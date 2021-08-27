import subprocess
import sys
from collections import deque
from functools import partial
from io import BufferedWriter
from pathlib import Path
from shutil import which
from subprocess import PIPE, STDOUT
from typing import Deque, Dict, List, Tuple

import trio
from trio import Event, MemoryReceiveChannel, MemorySendChannel, Process
from trio.abc import ReceiveStream, SendStream


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
    stdout_reference: Dict[str, bytes] = {"stdout": b""}
    watcher_channels: "Tuple[MemorySendChannel[bytes], MemoryReceiveChannel[bytes]]" = (
        trio.open_memory_channel(0)
    )
    printer_channels: "Tuple[MemorySendChannel[bytes], MemoryReceiveChannel[bytes]]" = (
        trio.open_memory_channel(0)
    )
    watcher_send_channel, watcher_receive_channel = watcher_channels
    printer_send_channel, printer_receive_channel = printer_channels

    async def printer(
        stdout_channel: "MemoryReceiveChannel[bytes]", print_buffer: BufferedWriter
    ) -> None:
        async with stdout_channel:
            async for chunk in stdout_channel:
                try:
                    print_buffer.write(chunk)
                except BlockingIOError:
                    pass
                print_buffer.flush()

    async def copier(
        stdout_stream: ReceiveStream,
        watcher_channel: "MemorySendChannel[bytes]",
        printer_channel: "MemorySendChannel[bytes]",
    ) -> None:
        async with stdout_stream, watcher_channel, printer_channel:
            async for chunk in stdout_stream:
                await printer_channel.send(chunk)
                await watcher_channel.send(chunk)

    async def watcher_recorder(
        stdout_channel: "MemoryReceiveChannel[bytes]",
        ref_dict: Dict[str, bytes],
        stdin_stream: SendStream,
        expect: bytes,
        response: bytes,
        timeout: float,
        process: Process,
    ) -> None:
        response_sent = False
        async with stdout_channel, stdin_stream:
            with trio.move_on_after(timeout):
                async for chunk in stdout_channel:
                    ref_dict["stdout"] += chunk
                    if not response_sent and expect in ref_dict["stdout"]:
                        print("watcher sending response...", flush=True)
                        await stdin_stream.send_all(response)
                        response_sent = True
                        print("watcher finished sending response...", flush=True)

            if response_sent:
                # the timeout expired, but the response was sent, so keep going
                # and let total timeout expire
                async for chunk in stdout_channel:
                    ref_dict["stdout"] += chunk

        if process.returncode == None:
            print("watcher expect timeout")
            process.kill()

    async with await trio.open_process(
        [
            sys.executable,
            "-c",
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
""",
        ],
        stdin=PIPE,
        stdout=PIPE,
        stderr=STDOUT,
    ) as process:

        async with trio.open_nursery() as nursery:
            nursery.start_soon(
                partial(
                    copier, process.stdout, watcher_send_channel, printer_send_channel
                )
            )
            nursery.start_soon(
                partial(printer, printer_receive_channel, sys.stdout.buffer)
            )
            nursery.start_soon(
                partial(
                    watcher_recorder,
                    watcher_receive_channel,
                    stdout_reference,
                    process.stdin,
                    b"hello",
                    b"hi\n",
                    expect_timeout,
                    process,
                ),
            )

            with trio.move_on_after(total_timeout):
                await process.wait()

            if process.returncode == None:
                print("total timeout")
                process.kill()

    stdout = stdout_reference["stdout"].decode()

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
