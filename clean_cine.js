const fs = require('fs');
let file = fs.readFileSync('Scripts/GameScenes/RoomCinematicEventDirector.gd', 'utf8');

const regex = /        # 先等待正常房间切换和动态检查点定位稳定，再开始事件播放；不重做房间同步，避免干扰正常切房逻辑。[\s\S]*?await get_tree\(\)\.physics_frame/;

if (regex.test(file)) {
	file = file.replace(regex, '');
	fs.writeFileSync('Scripts/GameScenes/RoomCinematicEventDirector.gd', file);
	console.log('removed rogue camera logic');
} else {
	console.log('not found');
}
