"""给 Flutter 生成的 AndroidManifest.xml 注入网络权限。

flutter create 出来的 release manifest 默认不带 INTERNET，
App 里要调大模型就必须补一条 uses-permission。
"""

import io
import os
import sys

PERMISSION = '<uses-permission android:name="android.permission.INTERNET"/>'
TARGET = os.path.join('android', 'app', 'src', 'main', 'AndroidManifest.xml')


def main():
    if not os.path.exists(TARGET):
        print('skip: %s 不存在（还没生成 android 目录？）' % TARGET)
        return 0
    with io.open(TARGET, encoding='utf-8') as f:
        source = f.read()

    if PERMISSION in source:
        print('ok: 已经有 INTERNET 权限')
        return 0

    lines = source.splitlines()
    out = []
    inserted = False
    for line in lines:
        if not inserted and '<application' in line:
            indent = line[: len(line) - len(line.lstrip())]
            out.append(indent + PERMISSION)
            inserted = True
        out.append(line)

    if not inserted:
        print('fail: manifest 里找不到 <application> 标签')
        return 1

    with io.open(TARGET, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out) + '\n')
    print('ok: 已注入 INTERNET 权限')
    return 0


if __name__ == '__main__':
    sys.exit(main())
