"""
shows how to make it easy to run a process and respond to its output, all while
echoing the process' output
"""
import sys
from contextlib import asynccontextmanager
from functools import partial
from subprocess import PIPE, STDOUT
from typing import TYPE_CHECKING

import trio

if TYPE_CHECKING:
    from io import BufferedWriter
    from typing import AsyncIterator, List, Tuple, Union

    from trio import MemoryReceiveChannel, MemorySendChannel, Process


# pylint: disable=too-many-instance-attributes,too-many-arguments
class Expect:
    """
    Manages running a process as a subprocess, and communicating with it, while
    echoing its output
    """

    def __init__(
        self,
        process: "Process",
        printer_send_channel: "MemorySendChannel[bytes]",
        printer_receive_channel: "MemoryReceiveChannel[bytes]",
        notifier_send_channel: "MemorySendChannel[bytes]",
        opened_notifier_receive_channel: "MemoryReceiveChannel[bytes]",
        print_buffer: "BufferedWriter" = sys.stdout.buffer,  # type: ignore
    ):
        self.process = process
        self.printer_send_channel = printer_send_channel
        self.printer_receive_channel = printer_receive_channel
        self.notifier_send_channel = notifier_send_channel
        self.opened_notifier_receive_channel = opened_notifier_receive_channel
        self.print_buffer = print_buffer
        self.stdout: bytes = b""
        self.response_sent = False

    # NOTE: may be able to be combined with copier_recorder()
    async def printer(
        self,
    ) -> None:
        "echoes the process' output, dropping data if necessary"
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
        """
        records the process' stdout, and mirrors it to printer()

        also sends notifications to expect() every time the process prints
        something
        """
        if not self.process:
            raise Exception("missing process; was this called inside a with statement?")

        assert (
            self.process.stdout is not None
        ), "process must be opened with stdout=PIPE and stderr=STDOUT"

        async with self.process.stdout, self.printer_send_channel, self.notifier_send_channel:
            async for chunk in self.process.stdout:
                # print(f"seen chunk: '{chunk!r}'", flush=True)
                self.stdout += chunk
                await self.printer_send_channel.send(chunk)

                # send notification
                # if it's full, that's fine: if expect() is run, it'll see
                # there's a "pending" notification and check stdout, then wait
                # for another notification
                try:
                    self.notifier_send_channel.send_nowait(b"")
                except trio.WouldBlock:
                    pass
                except trio.BrokenResourceError as err:
                    print(f"cause '{err.__cause__}'")
                    raise err

    async def expect(
        self,
        watch_for: bytes,
        respond_with: bytes,
    ) -> None:
        """
        called inside Expect.open_process()'s with block to watch for, and
        respond to, the process' output
        """
        if not self.process:
            raise Exception("missing process; was this called inside a with statement?")

        assert self.process.stdin is not None, "process must be opened with stdin=PIPE"

        # NOTE: This could be improved to show which responses were sent, and which
        # weren't
        self.response_sent = False
        async with self.opened_notifier_receive_channel.clone() as notifier_receive_channel:
            # print("expect --> opened notifier channel", flush=True)
            async for _ in notifier_receive_channel:
                # print("expect --> received chunk notification", flush=True)
                if not self.response_sent and watch_for in self.stdout:
                    print("expect --> sending response...", flush=True)
                    await self.process.stdin.send_all(respond_with)
                    self.response_sent = True
                    print("expect --> response sent", flush=True)

    @classmethod
    @asynccontextmanager
    async def open_process(
        cls, args: "Union[str, List[str]]"
    ) -> "AsyncIterator[Expect]":
        """
        entry point for using Expect()

        opens the process, opens a nursery, and starts the copier and printer

        this waits until the process is finished, so wrapping in a
        trio.move_on_after() is good to use as a timeout
        """
        printer_channels: (
            "Tuple[MemorySendChannel[bytes], MemoryReceiveChannel[bytes]]"
        ) = trio.open_memory_channel(1)
        printer_send_channel, printer_receive_channel = printer_channels
        notifier_channels: (
            "Tuple[MemorySendChannel[bytes], MemoryReceiveChannel[bytes]]"
        ) = trio.open_memory_channel(0)
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
    "demos Expect() using a Python script as a subprocess"
    assert (
        process_total_time > process_hello_time >= 0
    ), "process_total_time must be long enough for process_hello_time to elapse"
    process_wait_time = process_total_time - process_hello_time

    python_process_code = f"""
import time
print("process -> waiting for {process_hello_time} seconds", flush=True)

start = time.monotonic()
i = 1
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
i = 1
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

print("process -> thanks", flush=True)
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

            if not expect.response_sent and expect.process.returncode is None:
                print(f"\nexpect --> expect timeout ({expect_timeout}s)")
                expect.process.kill()

    if expect.response_sent and expect.process.returncode != 0:
        print(f"\nexpect --> total timeout ({total_timeout}s)")

    stdout = "\n".join(
        f"       --> {line}" for line in expect.stdout.decode().splitlines()
    )

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
            expect_timeout=3.0,
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
            total_timeout=7.0,
        )
    )
