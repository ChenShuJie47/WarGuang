---
name: afterimage-trail-local
overview: 在不追求极致性能的前提下，把残影从全局 `AfterimageManager` 解耦为“每个角色自包含”的 `AfterimageTrail` 组件；同时修正纯色块模式的轮廓透明度，让纯色块仍保持贴图轮廓。
todos:
  - id: shader-solid-alpha-fix
	content: 修正 `Assets/Shaders/AfterimageShader.gdshader`：`solid_color` 分支让 alpha 乘上纹理 alpha 以保持轮廓。
	status: pending
  - id: afterimage-instance-decouple
	content: 修改 `Scripts/Instances/Afterimage.gd`：移除对 `/root/AfterimageManager` 的回收依赖；改为回收到注入的本地 `pool_ref`；uniform 改从 cfg/组件提供。
	status: pending
  - id: add-afterimage-trail-component
	content: 新增 `Scripts/Components/AfterimageTrail.gd`：组件内维护 CanvasGroup + 各 action 对应的本地 AfterimagePool；提供 `get_interval()` 与 `spawn()` 给 Player 调用。
	status: pending
  - id: player-refactor-to-trail
	content: 修改 `Scripts/Player/Player.gd` + `Scenes/Player/Player.tscn`：用 `AfterimageTrail.spawn()` 替换 `AfterimageManager.spawn()`；用 `AfterimageTrail.get_interval()` 替换原 interval 引用；删除/停用 register_pool 逻辑与不再需要的回收路径。
	status: pending
  - id: verify-and-cleanup
	content: 手动验证 dash/black_dash/super_dash/jumpbox 表现一致性；确认纯色块轮廓正确；验证池耗尽场景；必要时瘦身 Player 中旧残影相关未使用代码。
	status: pending
isProject: false
---

### 最终推荐方案（相对 A/B 的选择）

在你放宽性能要求、强调“强独立性”的条件下，我更推荐一个“全新变体”：

- **不要让 `Player` 依赖全局 `AfterimageManager`**（去掉 `/root/AfterimageManager` 的耦合点）
- **每个需要残影的角色自己挂一个 `AfterimageTrail` 组件**（组件拥有自己的配置、对象池、生成调度）
- 复用你现有的 GPU 端 `AfterimageShader` 思路：淡入/淡出/缩放/漂移尽量放在 Shader 里
- 由于你接受“纯色块轮廓”方案，我会进一步**修正 Shader 的 `solid_color` 逻辑，让透明度仍由原贴图 `tex_color.a` 决定**，从而真正保持轮廓（避免变成整块矩形）

这基本是对“方案 B”的工程化落地：把“池+生成”收拢到组件内，让残影模块对 `Player`/其它使用者的耦合度尽可能低。

### 总体架构（目标数据流）

```mermaid
flowchart TD
  Player[Player状态机/输入逻辑] -->|触发: spawn(action, texture, pos, flip, move_dir, move_dist)| Trail[AfterimageTrail组件(本地池+本地调度)]
  Trail -->|借出实例| Pool[AfterimagePool(组件内)]
  Pool -->|initialize + shader params| Afterimage[Afterimage实例(自包含/回收到本地pool)]
  Afterimage --> Shader[AfterimageShader(纯色块轮廓+GPU淡入淡出+顶点漂移)]
  Afterimage -->|Timer到期: return to pool| Pool
```



### 关键改动点（为什么能满足你的要求）

1. **独立性**：`Afterimage` 不再通过 `get_node_or_null("/root/AfterimageManager")` 回收；回收到“自己的本地池/组件”。
2. **复用性（但不要求同类型跨场景复用）**：同一个 `AfterimageTrail` 组件可挂到其它角色节点上复用；每个角色独立配置。
3. **性能可控**：你不追求极致性能，因此可以保留“局部对象池”；如果未来想更进一步，仍可在组件内部做 LOD / FPS 降级。
4. **纯色块轮廓**：把 Shader 的 `solid_color` alpha 计算改成 `tex_color.a * color.a ...`，保证轮廓由原纹理决定。

### 具体实施计划（按步骤落地）

#### Step 1：修正纯色块轮廓（Shader 层）

- 修改 `[Assets/Shaders/AfterimageShader.gdshader]`：
  - 在 `solid_color` 分支里，把 `final_alpha` 从“只用 `color.a`”改为“乘上 `tex_color.a`”（保持轮廓透明度）。

**建议修改点**（概念表达，不贴大段最终代码）：

- 当前：`final_alpha = color.a * display_alpha`
- 期望：`final_alpha = tex_color.a * color.a * display_alpha`

同时保留你当前的三阶段透明度、UV 缩放与顶点漂移逻辑。

#### Step 2：让 Afterimage 实例从全局回收依赖中解耦

- 修改 `[Scripts/Instances/Afterimage.gd]`：
  1. 移除/避免硬编码依赖：
	- 删除 `return_to_pool()` 里对 `"/root/AfterimageManager"` 的查找逻辑。
  2. 增加“本地回收句柄”：
	- 增加成员 `var pool_ref: Node = null`（或强类型到 `AfterimagePool`）
	- 在 `initialize(...)` 末尾或 spawn 之后，由 `AfterimageTrail` 注入 `pool_ref`。
  3. Shader uniform 的来源改为“cfg/组件提供”，避免 `AfterimageManager.global_`*：
	- `fade_duration`、`fade_in_duration`、`scale_multiplier` 这些 uniform 不再从 AfterimageManager 读，而从 `cfg` 或组件参数读。

效果：`Afterimage` 完全自包含，只负责在 Timer 到期时回收给自己所属的本地池。

#### Step 3：新增本地组件 `AfterimageTrail`（组件封装池与发射）

- 新增文件 `[Scripts/Components/AfterimageTrail.gd]`（或你项目已有组件目录下同等路径）：
  - `AfterimageTrail` 内部持有：
	- 一个 `CanvasGroup`（批量渲染容器，减少层级影响）
	- 若干 `AfterimagePool`（按 action：`dash` / `black_dash` / `super_dash` / `jumpbox`）
	- 每个 action 的配置（颜色、lifetime、spawn_interval、pool_size、solid_color、fade_scale_effect 等）
  - 对外 API（最少化 Player 依赖）：
	- `func get_interval(action_key: String) -> float`
	- `func spawn(action_key: String, texture: Texture2D, position: Vector2, flip_h: bool, custom_scale: Vector2, move_dir: Vector2, move_dist: float) -> void`

组件内部逻辑：

- 在 `_ready()` 初始化各 action 的池（预创建，避免运行时 instantiate 抖动）
- `spawn(...)` 时：
  - 获取 `pool.get_available()`
  - 设置 shader 参数（move_direction/move_distance）
  - 调用 `afterimage.initialize(...)` 并注入 `pool_ref`

> 注意：你不强制同类型“跨情况复用”，所以配置可以简单地按 action_key 写死在组件里，不必做 profile 资源体系（但结构上仍是“可调”的 exporter）。

#### Step 4：改写 Player：从 AfterimageManager 转到 AfterimageTrail

- 修改 `[Scripts/Player/Player.gd]`：
  1. 删除/停用 `initialize_afterimage_pool()` 中的 `AfterimageManager.register_pool(...)` 注册逻辑。
  2. 在 `create_afterimage(...)` / `_create_afterimage_new(...)` 中，把：
	- `AfterimageManager.spawn(...)`
	- 替换为：`afterimage_trail.spawn(action_key, texture, spawn_position, flip_h, scale, move_direction, move_distance)`
  3. 在 `handle_afterimages(fixed_delta)` 中，把 interval 来源：
	- 从 `AfterimageManager.dash_afterimage_interval` 等
	- 替换为 `afterimage_trail.get_interval("dash")` 等（或直接用组件导出的值）。
  4. `return_afterimage(...)`：
	- 如果现在回收完全由 `Afterimage` 内置 Timer 驱动且回收到本地池，那么 Player 的 return 逻辑可以逐步移除。
	- 若你未来仍要强制清理残影，再在组件中提供 `clear_action(action_key)`。
- 修改 `[Scenes/Player/Player.tscn]`：
  - 在 `Player` 节点下新增子节点 `AfterimageTrail`（挂上 `AfterimageTrail.gd` 脚本）。
  - 把你原先在 `AfterimageManager` Inspector 中的参数（颜色/lifetime/interval/pool_size/solid_color/fade_scale_effect）迁移到组件对应导出字段。

#### Step 5：逐步清理与验证

- 清理：
  - 如果 Player 中存在“旧的本地池数组/回收接口”（例如 `jumpbox_afterimage_pool`、`available_jumpbox_afterimages` 等），且在当前路径下不再使用，可在验证完后进行瘦身。
- 验证（至少做这些检查）：
  1. `solid_color=true` 时，残影轮廓是否仍贴合角色形状（不应出现纯矩形）。
  2. `dash / black_dash / super_dash / jumpbox` 的淡入淡出、缩放消失、move 漂移方向是否与当前一致。
  3. 连续冲刺时不会报池耗尽（pool_size 是否足够）。

### 关于 AfterimageManager 的处理

为了降低风险：

- `project.godot` 中保留 `AfterimageManager` autoload 不改动也可以；但在新方案落地后，Player 不再使用它。
- 等你确认新残影表现完全正确后，再考虑移除 autoload 做一次“彻底清理”。

先整体查看目前游戏项目内容，了解基本的游戏架构，
然后重点查阅当前有关残影的相关脚本代码，现在针对以下任务，先给出你的理解，然后给出你的方案计划（先不要实际应用修改）：
1 告诉我目前残影移动强度的参数在哪里？
2 关于目前ManiacNPC的残影表现有两个错误：首先是残影图层大于npc本身图层（因为目前规定残影图层和player图层一致），
你能控制残影生成图层级别自动变化为使用者的图层级别吗（如果实现复杂，也可以只针对Maniac Move残影类型，让其生成的残影图层和npc一致），
另外是ManiacNPC在move状态但是没有移动时依旧产生残影，我希望修改残影生成逻辑为npc在静止时（速度为零）停止生成残影；
3 修改player超级冲刺逻辑：player在SUPERDASH和SUPERDASHSTART状态时禁止其方向修改（就是让player在超级冲刺充电状态和超级冲刺状态不能控制左右方向）。
