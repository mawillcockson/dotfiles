import subprocess
import sys
from collections import deque
from functools import partial
from io import BufferedWriter
from pathlib import Path
from shutil import which
from subprocess import PIPE, STDOUT
from typing import Deque, Dict, List

import trio
from trio import MemoryReceiveChannel, MemorySendChannel, Process
from trio._abc import ReceiveStream, SendStream


async def powershell():
    stdout_chunks: List[bytes] = []

    async with await trio.open_process(
        ";Start-Sleep -Milliseconds 200;".join(f'Write-Host "{i}"' for i in range(3)),
        stdin=None,
        stdout=PIPE,
        stderr=STDOUT,
        shell=True,
        executable=which("powershell"),
    ) as process:

        while process.returncode == None:
            chunk = await process.stdout.receive_some()
            if chunk:
                sys.stdout.buffer.write(chunk)
                sys.stdout.buffer.flush()
                stdout_chunks.append(chunk)

    process.stdout = b"".join(stdout_chunks)

    print(f"recorded stdout:\n{process.stdout.decode()}")


async def watcher_example() -> None:
    stdout_reference: Dict[str, bytes] = {"stdout": b""}

    async def watcher_copier(
        stdout_stream: ReceiveStream,
        ref_dict: Dict[str, bytes],
        print_stream: BufferedWriter,
        stdin_stream: SendStream,
        expect: bytes,
        response: bytes,
        process: Process,
    ) -> None:
        response_sent = False
        async with stdout_stream, stdin_stream:
            async for chunk in stdout_stream:
                ref_dict["stdout"] += chunk
                print_stream.write(chunk)
                print_stream.flush()
                if not response_sent and expect in ref_dict["stdout"]:
                    print("sending response...", flush=True)
                    await stdin_stream.send_all(response)
                    response_sent = True
                    print("finished sending response...", flush=True)

                if process.returncode != None:
                    return

    async with await trio.open_process(
        [
            sys.executable,
            "-c",
            """
print("process says hello", flush=True)
print(f"process received: {input()}", flush=True)
print("process says thanks", flush=True)
""",
        ],
        stdin=PIPE,
        stdout=PIPE,
        stderr=STDOUT,
    ) as process:

        async with trio.open_nursery() as nursery:
            nursery.start_soon(
                watcher_copier,
                process.stdout,
                stdout_reference,
                sys.stdout.buffer,
                process.stdin,
                b"hello",
                b"hi\n",
                process,
            )

            await process.wait()

    stdout = stdout_reference["stdout"].decode()

    print(f"recorded stdout:\n{stdout}")


async def main(args):
    stdout_chunks: List[bytes] = []
    copy_queue: Deque[bytes] = deque()

    async def recorder(
        in_stream: ReceiveStream, chunks: List[bytes], queue: Deque[bytes]
    ) -> None:
        async with in_stream:
            async for chunk in in_stream:
                chunks.append(chunk)
                queue.appendleft(chunk)

    async def copier(
        process: Process, out_stream: BufferedWriter, queue: Deque[bytes]
    ) -> None:
        while process.returncode == None:
            if queue:
                out_stream.write(queue.pop())
                out_stream.flush()
            await trio.sleep(0)

    async with await trio.open_process(
        args,
        stdin=None,
        stdout=PIPE,
        stderr=STDOUT,
    ) as process:

        async with trio.open_nursery() as nursery:
            nursery.start_soon(recorder, process.stdout, stdout_chunks, copy_queue)
            nursery.start_soon(copier, process, sys.stdout.buffer, copy_queue)

            await process.wait()

    process.stdout = b"".join(stdout_chunks)

    print(f"recorded stdout:\n{process.stdout.decode()}")


if __name__ == "__main__":
    args = [
        sys.executable,
        "-c",
        """
from time import sleep
for i in range(3):
    print(i, flush=True)
    sleep(0.2)
""",
    ]
    print("regular")
    subprocess.run(args)

    print("trio")
    trio.run(partial(main, args))

    print("watcher")
    trio.run(watcher_example)
