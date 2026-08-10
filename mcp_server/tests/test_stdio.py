# -*- coding: utf-8 -*-
"""stdio 协议握手测试：通过 mcp 官方 SDK 连接 server.py，列出工具并调用一个工具。"""
import asyncio
import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def main():
    params = StdioServerParameters(
        command=sys.executable,
        args=[os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "server.py")],
        cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    )
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            init = await session.initialize()
            print("=== initialize ===")
            print("server:", init.serverInfo.name, init.serverInfo.version)

            tools = await session.list_tools()
            print("\n=== tools ({}个) ===".format(len(tools.tools)))
            for t in tools.tools:
                print(" -", t.name)

            print("\n=== call list_shops ===")
            res = await session.call_tool("list_shops", {})
            for c in res.content:
                print(c.text[:400])

            print("\n=== call get_business_summary ===")
            res = await session.call_tool("get_business_summary", {
                "shop_name": "弹动官方旗舰店",
                "start_date": "2026-06-01",
                "end_date": "2026-06-30",
                "scope_key": "全店",
                "metric_key": "user_pay_amount",
            })
            for c in res.content:
                print(c.text[:400])

            print("\n=== 协议握手测试完成 ===")


if __name__ == "__main__":
    asyncio.run(main())
