import math
import subprocess
import sys
import time
from collections import deque
from contextlib import asynccontextmanager
from functools import partial
from io import BufferedWriter
from pathlib import Path
from shutil import which
from subprocess import PIPE, STDOUT
from typing import AsyncIterator, Deque, Dict, List, Tuple, Union

import trio
from trio import Event, MemoryReceiveChannel, MemorySendChannel, Nursery, Process
from trio.abc import ReceiveStream, SendStream


class Expect:
    def __init__(
        self,
        process: Process,
        printer_send_channel: "MemorySendChannel[bytes]",
        printer_receive_channel: "MemoryReceiveChannel[bytes]",
        notifier_send_channel: "MemorySendChannel[bytes]",
        opened_notifier_receive_channel: "MemoryReceiveChannel[bytes]",
        print_buffer: BufferedWriter = sys.stdout.buffer,
    ):
        self.process = process
        self.printer_send_channel = printer_send_channel
        self.printer_receive_channel = printer_receive_channel
        self.notifier_send_channel = notifier_send_channel
        self.opened_notifier_receive_channel = opened_notifier_receive_channel
        self.print_buffer = print_buffer
        self.stdout: bytes = b""
        self.response_sent = False

    async def printer(
        self,
    ) -> None:
        if not self.process:
            raise Exception("missing process; was this called inside a with statement?")

        async with self.printer_receive_channel:
            async for chunk in self.printer_receive_channel:
                try:
                    self.print_buffer.write(chunk)
                except BlockingIOError:
                    pass
                self.print_buffer.flush()

    async def copier_recorder(
        self,
    ) -> None:
        if not self.process:
            raise Exception("missing process; was this called inside a with statement?")

        async with self.process.stdout, self.printer_send_channel, self.notifier_send_channel:
            async for chunk in self.process.stdout:
                # print(f"seen chunk: '{chunk!r}'", flush=True)
                self.stdout += chunk
                await self.printer_send_channel.send(chunk)

                try:
                    self.notifier_send_channel.send_nowait(b"")
                except trio.WouldBlock:
                    pass

    async def expect(
        self,
        watch_for: bytes,
        respond_with: bytes,
    ) -> None:
        if not self.process:
            raise Exception("missing process; was this called inside a with statement?")

        self.response_sent = False
        async with self.opened_notifier_receive_channel.clone() as notifier_receive_channel:
            # print("expect --> opened notifier channel", flush=True)
            async for notification in notifier_receive_channel:
                # print("expect --> received chunk notification", flush=True)
                if not self.response_sent and watch_for in self.stdout:
                    print("expect --> sending response...", flush=True)
                    await self.process.stdin.send_all(respond_with)
                    self.response_sent = True
                    print("expect --> response sent", flush=True)

    @classmethod
    @asynccontextmanager
    async def open_process(cls, args: Union[str, List[str]]) -> "AsyncIterator[Expect]":
        printer_channels: "Tuple[MemorySendChannel[bytes], MemoryReceiveChannel[bytes]]" = trio.open_memory_channel(
            1
        )
        printer_send_channel, printer_receive_channel = printer_channels
        notifier_channels: "Tuple[MemorySendChannel[bytes], MemoryReceiveChannel[bytes]]" = trio.open_memory_channel(
            0
        )
        notifier_send_channel, notifier_receive_channel = notifier_channels

        async with notifier_receive_channel:
            async with await trio.open_process(
                args, stdin=PIPE, stdout=PIPE, stderr=STDOUT
            ) as process:
                async with trio.open_nursery() as nursery:
                    expect = cls(
                        process=process,
                        printer_send_channel=printer_send_channel,
                        printer_receive_channel=printer_receive_channel,
                        notifier_send_channel=notifier_send_channel,
                        opened_notifier_receive_channel=notifier_receive_channel,
                    )
                    nursery.start_soon(expect.copier_recorder)
                    nursery.start_soon(expect.printer)

                    yield expect

                    await expect.process.wait()


async def expect_example(
    process_hello_time: float = 0.0,
    process_total_time: float = 0.01,
    expect_timeout: float = 1.0,
    total_timeout: float = 1.0,
) -> None:
    assert (
        process_total_time > process_hello_time >= 0
    ), "process_total_time must be long enough for process_hello_time to elapse"
    process_wait_time = process_total_time - process_hello_time

    python_process_code = f"""
import time
print("process -> waiting for {process_hello_time} seconds", flush=True)

start = time.monotonic()
i = 0
while True:
    print(i, end=" ", flush=True)
    i += 1
    elapsed_time = time.monotonic() - start
    if elapsed_time >= {process_hello_time:f}:
        print("", flush=True)
        break
    elif elapsed_time < {process_hello_time:f} - 1:
        time.sleep(1)
    else:
        time_left = {process_hello_time:f} - elapsed_time
        time.sleep(time_left if time_left > 0 else 0)
        print("")
        break

print("process -> say hello", flush=True)
print(f"process -> received: {{input()}}", flush=True)
print("process -> waiting for {process_wait_time} seconds", flush=True)

start = time.monotonic()
i = 0
while True:
    print(i, end=" ", flush=True)
    i += 1
    elapsed_time = time.monotonic() - start
    if elapsed_time >= {process_hello_time:f}:
        print("", flush=True)
        break
    elif elapsed_time < {process_hello_time:f} - 1:
        time.sleep(1)
    else:
        time_left = {process_hello_time:f} - elapsed_time
        time.sleep(time_left if time_left > 0 else 0)
        print("")
        break

print("process -> says thanks", flush=True)
"""

    with trio.move_on_after(total_timeout):
        async with Expect.open_process(
            [sys.executable, "-c", python_process_code],
        ) as expect:

            with trio.move_on_after(expect_timeout):
                await expect.expect(
                    watch_for=b"hello",
                    respond_with=b"hi\n",
                )

            if not expect.response_sent and expect.process.returncode == None:
                print("expect --> expect timeout")
                expect.process.kill()

    if expect.response_sent and expect.process.returncode != 0:
        print("expect --> total timeout")

    stdout = "\n".join(f"       --> {line}" for line in expect.stdout.decode().splitlines())

    print(f"expect --> recorded stdout:\n{stdout}")


if __name__ == "__main__":
    print("## regular ##")
    trio.run(expect_example)

    print("")

    print("## no timeout ##")
    trio.run(
        partial(
            expect_example,
            process_hello_time=5.0,
            process_total_time=10.0,
            expect_timeout=7.0,
            total_timeout=15.0,
        )
    )

    print("")

    print("## expect timeout ##")
    trio.run(
        partial(
            expect_example,
            process_hello_time=5.0,
            process_total_time=50.0,
            expect_timeout=4.9,
            total_timeout=15.0,
        )
    )

    print("")

    print("## total timeout ##")
    trio.run(
        partial(
            expect_example,
            process_hello_time=5.0,
            process_total_time=50.0,
            expect_timeout=7.0,
            total_timeout=9.9,
        )
    )
