import subprocess
import sys
from collections import deque
from functools import partial
from io import BufferedWriter
from pathlib import Path
from shutil import which
from subprocess import PIPE, STDOUT
from typing import Deque, Dict, List, Tuple
from contextlib import AsycExitStack, AbstractAsyncContextManager

import trio
from trio import Event, MemoryReceiveChannel, MemorySendChannel, Process
from trio.abc import ReceiveStream, SendStream
import math


class Expect(AbstractAsyncContextManager):
    def __init__(self, args: Union[str, List[str]], shell: bool = False, print_buffer: BufferedWriter = sys.stdout.buffer):
        self.args = args
        self.shell = shell
        self.stdout: bytes = b""
        self.wait_for_process_exit = wait_for_process_exit
        self.print_buffer = print_buffer

        printer_channels: "Tuple[MemorySendChannel[bytes], MemoryReceiveChannel[bytes]]" = trio.open_memory_channel(1)
        self.printer_send_channel, self.printer_receive_channel = printer_channels
        notifier_channels: "Tuple[MemorySendChannel[bytes], MemoryReceiveChannel[bytes]]" = trio.open_memory_channel(0)
        self.notifier_send_channel, self.notifier_receive_channel = notifier_channels

        self.process: Optional[Process] = None
        self.response_sent = False
        self.exit_stack: Optional[AsycExitStack] = None

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
                self.stdout += chunk
                await printer_channel.send(chunk)

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
        async with self.notifier_receive_channel.copy() as notifier_receive_channel:
            async for notification in notifier_receive_channel:
                if not response_sent and watch_for in self.stdout:
                    await process.stdin.send_all(respond_with)
                    self.response_sent = True

    async def __aenter__(self) -> "Expect":
        if self.exit_stack:
            raise Exception("cannot reenter context manager")

        # I'm pretty sure the order here is important
        self.exit_stack = AsycExitStack()
        self.process = await self.exit_stack.enter_context(trio.open_process(args, stdin=PIPE, stdout=PIPE, stderr=STDOUT, shell=shell))
        self.nursery = await self.exit_stack.enter_context(trio.open_nursery())
        self.notifier_receive_channel = await self.exit_stack.enter_context(self.notifier_receive_channel)

        self.nursery.start_soon(self.copier_recorder)
        self.nursery.start_soon(self.printer)
        
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        if not self.exit_stack:
            raise Exception("context manager never entered")

        await self.exit_stack.aclose()

async def watcher_example(
    process_hello_time: float = 0.0,
    process_total_time: float = 0.01,
    expect_timeout: float = 1.0,
    total_timeout: float = 1.0,
) -> None:
    assert (
        process_total_time > process_hello_time >= 0
    ), "process_total_time must be long enough for process_hello_time to elapse"
    process_wait_time = process_total_time - process_hello_time

    python_process_code = \
f"""
import time
print("process thinking...", flush=True)
print("process waiting for {process_hello_time} seconds", flush=True)
time.sleep({process_hello_time:f})
print("process says hello", flush=True)
print(f"process received: {{input()}}", flush=True)
print("process waiting for {process_wait_time} seconds", flush=True)
time.sleep({process_wait_time})
print("process says thanks", flush=True)
"""

    with trio.move_on_after(total_timeout):
        async with await Expect(
            [
                sys.executable,
                "-c",
                python_process_code
            ],
        ) as expect:

            with trio.move_on_after(expect_timeout):
                await expect.expect(
                            b"hello",
                            b"hi\n",
                    )

            if not expect.response_sent and expect.process.returncode == None:
                print("total timeout")
                process.kill()

    stdout = expect.stdout.decode()

    print(f"recorded stdout:\n{stdout}")


if __name__ == "__main__":
    print("regular")
    trio.run(watcher_example)

    print("no timeout")
    trio.run(
        partial(
            watcher_example,
            process_hello_time=5.0,
            process_total_time=10.0,
            expect_timeout=7.0,
            total_timeout=15.0,
        )
    )

    print("expect timeout")
    trio.run(
        partial(
            watcher_example,
            process_hello_time=5.0,
            process_total_time=10.0,
            expect_timeout=4.9,
            total_timeout=15.0,
        )
    )

    print("total timeout")
    trio.run(
        partial(
            watcher_example,
            process_hello_time=5.0,
            process_total_time=10.0,
            expect_timeout=7.0,
            total_timeout=9.9,
        )
    )
