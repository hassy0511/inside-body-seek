"""すべてのモデル（キャラクター＋ステージ）を作って GLB に書き出す。

  python -m blender.build_all            # pip の bpy を使う
  blender -b -P blender/build_all.py     # Blender 本体を使う
  オプション --blend : blender/out/ に .blend も保存（Blender で開いて手直しできる）
"""
import sys

try:
    from . import characters, stages
except ImportError:
    import os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from blender import characters, stages

if __name__ == "__main__":
    save = "--blend" in sys.argv
    characters.build_all(save_blend=save)
    stages.build_all(save_blend=save)
    print("all done")
