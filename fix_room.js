const fs = require('fs');
let file = fs.readFileSync('Scripts/GameScenes/RoomCinematicEventDirector.gd', 'utf8');

file = file.replace(/        # 先等待正常房间切换和动态检查点定位稳定，再开始事件播放；不重做房间同步，避免干扰正常切房逻辑。[\r\n\s\S]*?player\.sync_camera_after_room_teleport\(\)[\r\n\s\S]*?await get_tree\(\)\.physics_frame/, '');

fs.writeFileSync('Scripts/GameScenes/RoomCinematicEventDirector.gd', file);
