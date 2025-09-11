-- config.lua - 全局配置
WINDOW_WIDTH = 1024
WINDOW_HEIGHT = 768

-- Tile设置
TILE_SIZE = 32
CHUNK_SIZE = 16  -- 每个chunk包含16x16个tile
VIEW_DISTANCE = 3  -- 加载周围3个chunk的距离

-- 目录设置
MODS_DIR = "mods"
SAVE_DIR = "saves"

-- 性能设置
MAX_CHUNKS_LOADED = 100
CHUNK_UNLOAD_DELAY = 5.0  -- 5秒后卸载不在视野内的chunk

-- 事件设置
MAX_EVENT_QUEUE_SIZE = 1000