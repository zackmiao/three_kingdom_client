# 三国杀 · 局域网联机（Flutter 客户端）

配套服务端见 `../Three_Kingdom`（Java 17，默认端口 9050）。客户端只做渲染与输入，
所有规则结算都在服务端完成，因此客户端可以重连、可以观战、可以被替换。

## 运行

```bash
flutter pub get
flutter run -d windows       # 或 -d macos / -d linux
```

打包：

```bash
flutter build windows --release
```

登录页填写服务端 IP（本机 `127.0.0.1`）、端口（`9050`）和昵称即可。

## 界面

| 页面 | 说明 |
| --- | --- |
| 登录页 `main.dart` | 连接服务端、握手、进入大厅 |
| 大厅 `views/lobby_screen.dart` | 建房（2~8 人）/ 加入房间，断线自动重连 |
| 房间 `views/room_screen.dart` | 4 格座位、**将面选将面板**、准备、房主加/删 AI、开局 |
| 对局 `views/game_room_screen.dart` | 圆桌布局、手牌区、装备/判定区、身份牌、操作倒计时 |

### 选将面板

服务端在进房时下发 `HERO_LIST`，客户端据此渲染选将面板：

- 6 列将面缩略图（图片来自 `assets/heroes/`，缺失时自动退化为势力色渐变 + 姓名）；
- 顶部按扩展包筛选（全部 / 标准 / 谋攻篇-能包 / 知包 / 同包 / 识包 / 虞包）；
- 底部实时显示所选武将的势力、体力与技能原文；
- 已被其他玩家占用的武将不再出现（不可重复选将）。

### 对局内

- **将面立绘**直接铺在席位卡上，配合体力条、身份徽记、距离提示（距N）、横置/标记与阵亡遮罩；
- 谋攻篇主动技（武圣 / 乱击 / 突袭 / 扬威 / 国色 / 明策）以技能按钮形式出现，点按钮后按提示选牌/选目标再点“确定”；
- 服务端要求选目标时（`【选择目标】` 前缀提示），直接点击席位即可，确认后把目标 ID 回传；
- 响应倒计时圆环（常规 25 秒，无懈 5 秒），超时自动放弃。

对局页支持：

- **拖拽出牌**：把手牌拖到对手席位上即可指定目标；
- **点选出牌**：先点手牌，再点席位，最后点「确定」；
- **技能按钮**：仁德 / 制衡 / 除害 / 丈八出杀（按武将或武器动态出现）；
- **响应倒计时**：圆形进度条显示服务端等待时间，超时自动 PASS；
- **身份与阶段**：顶部显示自己的身份，席位卡显示当前回合、阶段、体力条、横置/标记、明置身份（主公/阵亡者）；
- **弹窗**：五谷选牌、拆牌/顺手选区域、火攻展示、拼点、判定牌动画；
- **战况日志**：右侧抽屉查看完整对局记录。

## 代码结构

```
lib/
├ main.dart                 登录页
├ models/                   CardModel / OpponentModel / SkillModel / RoomMemberModel
├ network/
│  ├ command.dart           与服务端 Command 枚举一一对应
│  ├ packet.dart            `命令|发送者|数据` 编解码
│  └ socket_service.dart    TCP 连接、行解析、断线通知与自动重连
└ views/
   ├ lobby_screen.dart
   ├ room_screen.dart
   ├ game_room_screen.dart
   ├ components/            手牌区、席位卡、装备栏、提示栏、箭头绘制、日志
   └ dialogs/               五谷、区域选择、火攻、拼点、判定
```

## 素材说明

`assets/heroes/*.jpg` 为武将**将面立绘**，取自「三国杀 WIKI」（`wiki.biligame.com/msgs`）的公开武将页，
仅用于本地学习与局域网联机娱乐，版权归游卡桌游 / 哔哩哔哩 WIKI 原作者所有，请勿用于商业用途。
如需替换为自己的素材，把同名 `.jpg` 丢进 `assets/heroes/` 即可（没有图片的武将会自动显示势力色占位卡面）。

## 与服务端的约定

- 收到 `SYNC_STATE` 即整体刷新本地状态，字段为 `键:值|键:值`（武将/HP/DECK/SKILLS/EQUIP/JUDGE/MARKS/OPPONENTS/CARDS/TURN/PHASE/ROLE/ALIVEC/ROUND/TIMEOUT）。
- 所有对服务端询问的回应都通过 `RESPOND_CARD` 发送，格式见服务端 README。
- `LEAVE_ROOM` 表示离开房间但保持连接（回到大厅可继续建房）；`DISCONNECT` 才会真正断开。
