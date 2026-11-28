# 服务端逐牌播报与 payload 清单（供 card-client-matrix.md 引用）

来源仓库：`G:\desk\Three_Kingdom`。行号在下方每个单元格内写全。
路径缩写：`<H>` = `G:\desk\Three_Kingdom\src\main\java\com\threekingdom\engine\handler`；`<E>` = `G:\desk\Three_Kingdom\src\main\java\com\threekingdom\engine`；`<M>` = `G:\desk\Three_Kingdom\src\main\java\com\threekingdom\model`。

牌型全集以 `<M>\CardType.java` 为准：第 5-40 行共 30 个枚举（基本 6 / 非延时锦囊 11 / 延时锦囊 3 / 装备 10）。

## A. 五条广播通道与 payload 字段顺序

| 通道 | 发送点 | payload 字段顺序 |
| --- | --- | --- |
| `BROADCAST_MSG` | `<E>\GameContext.java:414-420`（`broadcast(String)`） | 无结构化字段，`data` 就是中文原文（含 emoji）；`from` 恒为 `SERVER` |
| `CARD_PLAYED` | `<E>\GameContext.java:474-490`（`broadcastCardPlayed`） | 7 段：`sourceId` \| `sourceName` \| `typeKey` \| `suitKey` \| `point` \| `cardName` \| `targets` |
| `CARD_REVEALED` | `<E>\GameContext.java:450-455`（`broadcastCardRevealed`） | 9 段：`ownerId` \| `ownerName` \| `actorId` \| `actorName` \| `typeKey` \| `suitKey` \| `point` \| `cardName` \| `action` |
| `CARD_FLOW` | `<E>\GameEngine.java:198-200`（`broadcastHandFlow`） | 3 段：`playerId` \| `playerName` \| `delta`（整数，可负） |
| `SHOW_JUDGE_RESULT` | `<H>\JudgePhaseHandler.java:90-96`；`<H>\CombatResolver.java:265-273` | 7 段：`玩家名` \| `锦囊名` \| `判定牌描述` \| `typeKey` \| `suitKey` \| `point` \| `判定含义` |

字段细节（客户端解析必须注意）：

- `typeKey` = `CardType.name()`（英文枚举名，对应客户端 `assets/cards/<KEY>.jpg`）；`suitKey` = `Suit.name()`（`SPADE/HEART/CLUB/DIAMOND`，null 兜底 `SPADE`）；`point` = `HandlerUtil.pointStr`，1/11/12/13 → `A/J/Q/K`，其余为数字字符串（`<H>\HandlerUtil.java:46-54`）。
- `CARD_PLAYED` 的 `cardName` 取 `card.getType().getName()`（牌型中文名，如 `杀`）；`CARD_REVEALED` 的 `cardName` 取 `card.getName()`（可能是专属名，如 `的卢`，兜底同牌型名，`<M>\Card.java:33-35`）。
- `CARD_PLAYED` 的 `targets` 写法：`id:name,id:name`；**无目标时该段为空串，但末尾的 `|` 仍在**，即 `sourceId|sourceName|typeKey|suitKey|point|cardName|`。
- `SHOW_JUDGE_RESULT` 第 1 段是**玩家中文名**（不是 id）；第 3 段 `cardLabel` 形如 `杀【黑桃7】`（`<H>\HandlerUtil.java:56-59`，花色中文取自 `<M>\Suit.java:7-10`：黑桃/红桃/草花/方片）。
- `CARD_PLAYED` 发送时会顺带写入「烈弓」记录花色（`<E>\GameContext.java:468-473`），客户端无感。

## B. 第一批 12 种：基本牌 + 单目标锦囊

| 牌型 | 触发点 | BROADCAST_MSG 原文 | 相关 payload 字段顺序 |
| --- | --- | --- | --- |
| 杀 | `<H>\CardPlayDispatcher.java:322` | `★ %s 对 %s 使用了 %s`（使用者名 / 目标名 / cardLabel） | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:324`，7 段，`targets` 为单个 `id:name` |
| 杀 | `<H>\CardPlayDispatcher.java:294` | `请先指定【杀】的目标！` | — |
| 杀 | `<H>\CardPlayDispatcher.java:302` | `%s 本回合出【杀】次数已达上限！` | — |
| 杀 | `<H>\CardPlayDispatcher.java:309` | `【距离受限】%s 与 %s 距离 %d，超出攻击范围 %d！` | — |
| 杀 | `<H>\CardPlayDispatcher.java:289` | `【烈弓】你没有装备武器，只能将【杀】当普通【杀】使用。` | — |
| 杀 | `<H>\CardPlayDispatcher.java:329` | 震袭（若有该技能）先弃其手牌，无专属文案 | — |
| 杀 | `<H>\CombatResolver.java:39` | `🛡 %s 的【藤甲】使普通%s无效！`（仅普通杀） | — |
| 杀 | `<H>\CombatResolver.java:45` | `🛡 %s 的【仁王盾】使黑色%s无效！`（黑桃/草花杀） | — |
| 杀 | `<H>\CombatResolver.java:61` | `【铁骑】%s 的%s指定了 %s，其不能使用【闪】响应！` | — |
| 杀 | `<H>\CombatResolver.java:84` | `【咆哮】%s 的%s不可被响应！` | — |
| 杀 | `<H>\CombatResolver.java:174` | `【烈弓】%s 已记录 %d 种花色，亮出牌堆顶 %d 张牌。` | — |
| 杀 | `<H>\CombatResolver.java:184` | `【烈弓】亮出 %s→ 同花色 %d 张。` | — |
| 杀 | `<H>\CombatResolver.java:242` | `【镇主】%s 的【杀】不可被响应，%s 无法使用【闪】。` | — |
| 杀 | `<H>\CombatResolver.java:252` | `【无双】%s 的【杀】需要两张【闪】才能抵消！` | — |
| 杀 | `<H>\CombatResolver.java:261` | `🔮 %s 的【八卦阵】判定：%s → %s`（末段 `红色，视为打出【闪】！` 或 `黑色，判定失败`） | `SHOW_JUDGE_RESULT` @`<H>\CombatResolver.java:265-273`，7 段，第 2 段固定 `八卦阵` |
| 杀 | `<H>\CombatResolver.java:297` | `【烈弓】%s 的 %s 属于已记录花色，不能用来响应！` | — |
| 杀 | `<H>\CombatResolver.java:305` | `✔ %s 打出 %s 躲避了攻击！` | — |
| 杀 | `<H>\CombatResolver.java:310` | `【倾国】%s 将黑色 %s 当【闪】打出！` | — |
| 杀 | `<H>\CombatResolver.java:317` | `【龙胆】%s 消耗 1 点蓄力，将 %s 当【闪】打出！` | — |
| 杀 | `<H>\CombatResolver.java:322` | `%s 尝试用 %s 闪避，但该牌无法作为【闪】。` | — |
| 杀 | `<H>\CombatResolver.java:99` | `🪓 %s 发动【贯石斧】，弃两张牌强制命中！` | — |
| 杀 | `<H>\CombatResolver.java:113` | `🍶 %s 的【酒】生效，本次伤害 +%d！` | — |
| 杀 | `<H>\CombatResolver.java:123` | `【无双】对方未能响应，本次伤害 +1。` | — |
| 杀 | `<H>\CombatResolver.java:129` | `【烈弓】%s 的【杀】伤害 +%d。` | — |
| 杀 | `<H>\CombatResolver.java:137` | `【义绝】%s 防止了对 %s 的致命伤害。` | — |
| 杀 | `<H>\CombatResolver.java:210` | `【流离】没有符合条件的目标，发动失败。` | — |
| 杀 | `<H>\CombatResolver.java:224` | `【流离】%s 弃置 %s，将【杀】转移给 %s！` | — |
| 杀 | `<H>\CombatResolver.java:158` | `【铁骑·直取敌营】%s 获得 %s 的一张牌。` | — |
| 杀 | `<H>\CombatResolver.java:163` | `【铁骑·扰阵疲敌】%s 摸两张牌。` | — |
| 杀（命中后） | `<H>\DamageResolver.java:126` | `⚔ %s 受到 %d 点伤害%s，剩余体力 %d/%d`（第 3 段为 `（火焰）`/`（雷电）`/空串） | — |
| 杀（命中后） | `<H>\DamageResolver.java:56` | `%s 的【白银狮子】生效，将伤害锁定为 1 点！`（无 emoji） | — |
| 杀（命中后） | `<H>\DamageResolver.java:60` | `%s 穿戴【藤甲】，受到火焰伤害 +1！` | — |
| 杀（命中后） | `<H>\DamageResolver.java:79` | `🛡 %s 的【护甲】抵消了 %d 点伤害（剩余护甲 %d）。` | — |
| 杀（命中后） | `<H>\DamageResolver.java:91` | `%s 的护甲吸收了全部伤害。` | — |
| 火杀 | 共用杀分支 `<H>\CardPlayDispatcher.java:285-334` | 同「杀」全部文案 | `CARD_PLAYED` 的 `typeKey` 为 `FIRE_SHA` |
| 火杀 | `<H>\CombatResolver.java:142` | 无专属文案；伤害属性 `FIRE` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:324` |
| 火杀 | `<H>\DamageResolver.java:146` | `⚡ %s 处于连环状态，属性伤害开始传导！` | — |
| 火杀 | `<H>\DamageResolver.java:150` | `⚡ 铁索传导！%s 解除横置并受到 %d 点传导伤害。` | — |
| 雷杀 | 共用杀分支 `<H>\CardPlayDispatcher.java:285-334` | 同「杀」全部文案 | `CARD_PLAYED` 的 `typeKey` 为 `THUNDER_SHA` |
| 雷杀 | `<H>\CombatResolver.java:143` | 无专属文案；伤害属性 `THUNDER` | — |
| 闪 | `<H>\CardPlayDispatcher.java:501` | `%s 暂不支持主动使用此牌。`（主动使用被拒） | 不发 `CARD_PLAYED` |
| 闪 | `<H>\CombatResolver.java:305` | `✔ %s 打出 %s 躲避了攻击！`（作为响应打出） | 不发 `CARD_PLAYED` |
| 闪 | `<H>\TrickResolver.java:208` | `%s 打出 %s 躲过了万箭齐发。` | — |
| 桃 | `<H>\CardPlayDispatcher.java:352` | `★ %s 使用【桃】，回复 %d 点体力 (HP: %d/%d)` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:354`，7 段，`targets` = 自己 `id:name` |
| 桃 | `<H>\CardPlayDispatcher.java:339` | `%s 体力已满，不能使用【桃】。` | — |
| 桃 | `<H>\CardPlayDispatcher.java:349` | `★ %s的%s 触发增强：%s，本次合计 %d 点%s`（潜龙/两仪，模板见 `<H>\CardEnhancer.java:74-78`） | — |
| 桃（濒死救援） | `<H>\DyingResolver.java:75` | `❤ %s 使用了 %s，为 %s 回复 %d 点体力 (HP: %d/%d)` | — |
| 桃（濒死，无效牌） | `<H>\DyingResolver.java:65` | `%s 尝试用 %s 救援，但该牌不能用于救援。` | — |
| 酒 | `<H>\CardPlayDispatcher.java:524` | `🍶 %s 使用%s，本回合下一张【杀】伤害 +1。`（%2 = `【酒】`，周处乡害时为 `【乡害·酒】`，见 `:368`） | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:526`，7 段，`targets` = 自己 |
| 酒 | `<H>\CardPlayDispatcher.java:518` | `%s 本回合已经使用过【酒】了。` | — |
| 决斗 | `<H>\CardPlayDispatcher.java:479` | `★ %s 对 %s 使用了 %s` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:481`，7 段，`targets` 单个 |
| 决斗 | `<H>\TrickResolver.java:126` | `⚔ %s 与 %s 开始【决斗】！` | — |
| 决斗 | `<H>\TrickResolver.java:141` | `%s 打出 %s 继续决斗。` | — |
| 决斗 | `<H>\TrickResolver.java:149` | `【决斗】结算：%s 未能出杀，受到 1 点伤害。` | — |
| 决斗 | `<H>\TrickResolver.java:118` | `【决斗】目标无效，牌已弃置。` | — |
| 决斗 | `<H>\TrickResolver.java:488` | `【决斗】打出的【杀】数量不足，决斗失败。` | — |
| 决斗 | `<H>\TrickResolver.java:493` | `%s 的响应中包含非【杀】牌，决斗失败。` | — |
| 决斗 | `<H>\TrickResolver.java:514` | `【决斗】打出的【杀】数量不足，决斗失败。`（成务补齐失败分支） | — |
| 决斗 | `<H>\TrickResolver.java:520` | `%s 的响应中包含非【杀】牌，决斗失败。` | — |
| 火攻 | `<H>\CardPlayDispatcher.java:479` | `★ %s 对 %s 使用了 %s` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:481`，7 段，`targets` 单个 |
| 火攻 | `<H>\TrickResolver.java:297` | `🔥 %s 展示了 %s。` | — |
| 火攻 | `<H>\TrickResolver.java:314` | 无专属文案；弃同花色牌后发 `CARD_REVEALED` | `CARD_REVEALED` @`<H>\TrickResolver.java:314`，9 段，`action=DISCARD`，`owner=actor=使用者` |
| 火攻 | `<H>\TrickResolver.java:315` | `🔥 %s 弃置同花色 %s，火攻命中！` | — |
| 火攻 | `<H>\TrickResolver.java:319` | `【火攻】%s 的牌花色不符，火攻落空。` | — |
| 火攻 | `<H>\TrickResolver.java:322` | `【火攻】使用者放弃了加伤。` | — |
| 火攻 | `<H>\TrickResolver.java:283` | `【火攻】目标没有手牌，无法生效。` | — |
| 无中生有 | 无「使用了」文案（仅结构化包） | — | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:430`，7 段，`targets` = 自己 |
| 无中生有 | `<H>\TrickResolver.java:108` | `★ %s 使用【无中生有】，摸了 %d 张牌。` | — |
| 无中生有 | `<H>\TrickResolver.java:110` | `【两仪】【无中生有】的效果结算两次。` | — |
| 无中生有 | `<H>\TrickResolver.java:102` | `【无中生有】被【无懈可击】抵消！` | — |
| 过河拆桥 | `<H>\CardPlayDispatcher.java:479` | `★ %s 对 %s 使用了 %s` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:481`，7 段，`targets` 单个 |
| 过河拆桥 | `<H>\TrickResolver.java:56` | 无专属文案；拆牌后发 `CARD_REVEALED` | `CARD_REVEALED` @`<H>\TrickResolver.java:56`，9 段，`action=DISCARD`，`owner`=被拆者、`actor`=被拆者 |
| 过河拆桥 | `<H>\TrickResolver.java:57` | `★ %s 弃置了 %s 的 %s。` | — |
| 过河拆桥 | `<H>\TrickResolver.java:44` | `【过河拆桥】目标无效，牌已弃置。` | — |
| 过河拆桥 | `<H>\TrickResolver.java:388` | `%s 没有任何牌可选择，%s 未产生效果。` | — |
| 过河拆桥 | `<H>\TrickResolver.java:95` | `【昭然】%s %s了 %s 的牌，获得 1 个「社」（当前 %d 个）。` | — |
| 顺手牵羊 | `<H>\CardPlayDispatcher.java:479` | `★ %s 对 %s 使用了 %s` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:481`，7 段，`targets` 单个 |
| 顺手牵羊 | `<H>\TrickResolver.java:79` | 无专属文案；得牌后发 `CARD_REVEALED` | `CARD_REVEALED` @`<H>\TrickResolver.java:79`，9 段，`action=GAIN`，`owner`=被拿者、`actor`=使用者 |
| 顺手牵羊 | `<H>\TrickResolver.java:80` | `★ %s 获得了 %s 的 %s。` | — |
| 顺手牵羊 | `<H>\CardPlayDispatcher.java:474` | `【顺手牵羊】只能对距离 1 以内的角色使用！` | — |
| 顺手牵羊 | `<H>\TrickResolver.java:67` | `【顺手牵羊】目标无效，牌已弃置。` | — |
| 无懈可击 | `<H>\CardPlayDispatcher.java:497` | `【无懈可击】只能在他人使用锦囊时打出，不能主动使用。` | 主动使用不发包 |
| 无懈可击 | `<H>\WuXieChainHandler.java:104` | `★ %s 打出【无懈可击】！当前结算状态：%s`（末段 `【锦囊效果被抵消】` 或 `【锦囊效果恢复】`） | `CARD_PLAYED` @`<H>\WuXieChainHandler.java:106`，7 段，`targets` **空串**（末尾仍留 `|`） |
| 无懈可击 | `<H>\WuXieChainHandler.java:55-56` | 询问提示：`【无懈可击询问】是否对【%s】(目标:%s) 打出【无懈可击】？(放弃点 PASS)` | `ASK_RESPONSE`（非广播） |
| 任意锦囊被抵消 | `<H>\TrickResolver.java:49` | `【过河拆桥】被【无懈可击】抵消！` | — |
| 任意锦囊被抵消 | `<H>\TrickResolver.java:72` | `【顺手牵羊】被【无懈可击】抵消！` | — |
| 任意锦囊被抵消 | `<H>\TrickResolver.java:123` | `【决斗】被【无懈可击】抵消！` | — |
| 任意锦囊被抵消 | `<H>\TrickResolver.java:288` | `【火攻】被【无懈可击】抵消！` | — |

## C. 第二批 18 种：群体锦囊 / 延时锦囊 / 装备

| 牌型 | 触发点 | BROADCAST_MSG 原文 | 相关 payload 字段顺序 |
| --- | --- | --- | --- |
| 南蛮入侵 | 无「使用了」文案（仅结构化包） | — | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:452`，7 段，`targets` = 除自己外全部存活角色 |
| 南蛮入侵 | `<H>\TrickResolver.java:168` | `📢 【南蛮入侵】来袭，所有其他角色需打出【杀】！` | — |
| 南蛮入侵 | `<H>\TrickResolver.java:173` | `【南蛮入侵】对 %s 的结算被【无懈可击】抵消。` | — |
| 南蛮入侵 | `<H>\TrickResolver.java:177` | `🛡 %s 的【藤甲】使【南蛮入侵】无效。` | — |
| 南蛮入侵 | `<H>\TrickResolver.java:184` | `%s 打出 %s 抵挡了南蛮入侵。` | — |
| 南蛮入侵 | `<H>\TrickResolver.java:466` | `%s 尝试用 %s 响应，但牌类型不符。` | — |
| 万箭齐发 | 无「使用了」文案（仅结构化包） | — | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:458`，7 段，`targets` = 除自己外全部存活角色 |
| 万箭齐发 | `<H>\TrickResolver.java:193` | `🏹 【万箭齐发】来袭，所有其他角色需打出【闪】！` | — |
| 万箭齐发 | `<H>\TrickResolver.java:197` | `【万箭齐发】对 %s 的结算被【无懈可击】抵消。` | — |
| 万箭齐发 | `<H>\TrickResolver.java:201` | `🛡 %s 的【藤甲】使【万箭齐发】无效。` | — |
| 万箭齐发 | `<H>\TrickResolver.java:208` | `%s 打出 %s 躲过了万箭齐发。` | — |
| 桃园结义 | 无「使用了」文案（仅结构化包） | — | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:439`，7 段，`targets` = 全部存活角色（含自己） |
| 桃园结义 | `<H>\TrickResolver.java:217` | `🌸 【桃园结义】全场回复 1 点体力！` | — |
| 桃园结义 | `<H>\TrickResolver.java:221` | `【桃园结义】对 %s 的回复被【无懈可击】抵消。` | — |
| 桃园结义 | `<H>\TrickResolver.java:226` | `❤ %s 回复 %d 点体力 (HP: %d/%d)` | — |
| 五谷丰登 | 无「使用了」文案（仅结构化包） | — | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:445`，7 段，`targets` = 全部存活角色（含自己） |
| 五谷丰登 | `<H>\TrickResolver.java:245` | `🌾 【五谷丰登】翻出：` + 牌面列表（`、` 连接 cardLabel） | — |
| 五谷丰登 | `<H>\TrickResolver.java:252` | `🌾 轮到 %s 从五谷丰登里选一张牌…` | `ASK_WU_GU` payload @`<H>\TrickResolver.java:436-446`：选牌项 `idx=描述\|typeKey\|suitKey\|point`，已被拿走的项 `t\|拿牌者名\|描述\|typeKey\|suitKey\|point`，多项以 `;` 连接 |
| 五谷丰登 | `<H>\TrickResolver.java:255` | `【五谷丰登】%s 的选牌被【无懈可击】抵消，本次不能拿牌。` | — |
| 五谷丰登 | `<H>\TrickResolver.java:267` | `%s 挑选了 %s。` | — |
| 五谷丰登 | `<H>\TrickResolver.java:240` | `牌堆已空，【五谷丰登】无牌可翻。` | — |
| 铁索连环 | 无「使用了」文案（仅结构化包） | — | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:423`（**先发包再结算**），7 段，`targets` = 选中的目标列表（重铸时为空串） |
| 铁索连环 | `<H>\TrickResolver.java:351` | `⛓ %s 进入横置（连环）状态。` | — |
| 铁索连环 | `<H>\TrickResolver.java:348` | `⛓ %s 解除了横置（连环）状态。` | — |
| 铁索连环 | `<H>\TrickResolver.java:335` | `♻ %s 重铸【铁索连环】，弃置此牌并摸了 1 张牌。`（重铸入口 `<H>\CardPlayDispatcher.java:186-187` → `:716-725`） | — |
| 铁索连环 | `<H>\TrickResolver.java:341` | `【铁索连环】被【无懈可击】抵消！` | — |
| 铁索连环 | `<H>\SimaZhaoSupport.java:84` | `【昭心】%s 免疫横置（铁索连环）。` | — |
| 乐不思蜀 | 无「使用了」文案（仅结构化包） | — | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:408`（**后于放置播报**），7 段，`targets` 单个 |
| 乐不思蜀 | `<H>\TrickResolver.java:374` | `🈲 %s 将 %s 置于 %s 的判定区。`（使用者 / cardLabel / 目标名） | — |
| 乐不思蜀 | `<H>\TrickResolver.java:369` | `%s 的判定区已有【%s】，无法重复放置。` | — |
| 乐不思蜀 | `<H>\TrickResolver.java:364` | `目标无效，延时锦囊已弃置。` | — |
| 乐不思蜀 | `<H>\JudgePhaseHandler.java:49` | `⚖ 开始结算 %s 判定区的 【%s】...` | — |
| 乐不思蜀 | `<H>\JudgePhaseHandler.java:65` | `⚖ 【判定结果】翻出判定牌: %s`（`Card.toString()` 结果） | `SHOW_JUDGE_RESULT` @`<H>\JudgePhaseHandler.java:90-96`，7 段，第 2 段 `乐不思蜀` |
| 乐不思蜀 | `<H>\JudgePhaseHandler.java:103` | `❌ %s 【乐不思蜀】判定生效！跳过本回合出牌阶段！` | — |
| 乐不思蜀 | `<H>\JudgePhaseHandler.java:105` | `✔ %s 【乐不思蜀】判定为红桃，判定失效！` | — |
| 乐不思蜀 | `<H>\JudgePhaseHandler.java:73-74` | `SHOW_JUDGE_RESULT` 第 7 段文案：`非红桃 → 判定生效：[乐不思蜀] 跳过出牌阶段` / `红桃 → 判定失效：本回合正常出牌` | — |
| 兵粮寸断 | 无「使用了」文案（仅结构化包） | — | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:408`，7 段，`targets` 单个 |
| 兵粮寸断 | `<H>\CardPlayDispatcher.java:402` | `【兵粮寸断】只能对距离 1 以内的角色使用！` | — |
| 兵粮寸断 | `<H>\TrickResolver.java:374` | `🈲 %s 将 %s 置于 %s 的判定区。` | — |
| 兵粮寸断 | `<H>\JudgePhaseHandler.java:111` | `❌ %s 【兵粮寸断】判定生效！跳过本回合摸牌阶段！` | — |
| 兵粮寸断 | `<H>\JudgePhaseHandler.java:113` | `✔ %s 【兵粮寸断】判定为草花，判定失效！` | — |
| 兵粮寸断 | `<H>\JudgePhaseHandler.java:77-78` | `SHOW_JUDGE_RESULT` 第 7 段文案：`非草花 → 判定生效：[兵粮寸断] 跳过摸牌阶段` / `草花 → 判定失效：本回合正常摸牌` | — |
| 闪电 | **不发 `CARD_PLAYED`**（`<H>\CardPlayDispatcher.java:388-392` 直接 `placeDelayTrick` 后 return） | — | 无结构化包，只有下面两行文本 |
| 闪电 | `<H>\TrickResolver.java:374` | `🈲 %s 将 %s 置于 %s 的判定区。`（使用者与目标都是自己） | — |
| 闪电 | `<H>\JudgePhaseHandler.java:119` | `⚡⚡⚡ %s 【闪电】判定生效！受到 3 点雷电伤害！` | — |
| 闪电 | `<H>\JudgePhaseHandler.java:127` | `✔ %s 【闪电】未生效，移动至下家 %s 的判定区！` | — |
| 闪电 | `<H>\JudgePhaseHandler.java:82-83` | `SHOW_JUDGE_RESULT` 第 7 段文案：`黑桃 2~9 → 判定生效：受到 3 点雷电伤害` / `非黑桃 2~9 → 判定失效：[闪电] 移至下家` | — |
| 诸葛连弩 | `<H>\CardPlayDispatcher.java:381` | `★ %s 装备了 【%s】%s`（第 3 段武器为 `（攻击范围 %d）`，马为 `（距离修正）`，其余为空串） | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:382`，7 段，`targets` **空串**（末尾仍留 `\|`） |
| 诸葛连弩 | `G:\desk\Three_Kingdom\src\main\java\com\threekingdom\model\Player.java:298-310` | 无专属文案；`canUseSha()` 返回 true，故不再触发 `本回合出【杀】次数已达上限！` | — |
| 丈八蛇矛 | `<H>\CardPlayDispatcher.java:381` | `★ %s 装备了 【%s】%s` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:382`，`targets` 空串 |
| 丈八蛇矛 | `<H>\CardPlayDispatcher.java:707` | `★ %s 发动【丈八蛇矛】，将两张牌当【杀】对 %s 使用！` | **不发 `CARD_PLAYED`**（结算走 `performSha`，`<H>\CardPlayDispatcher.java:711`） |
| 丈八蛇矛 | `<H>\CardPlayDispatcher.java:692` | `【丈八蛇矛】需要恰好两张手牌。` | — |
| 丈八蛇矛 | `<H>\CardPlayDispatcher.java:670` | `你没有装备【丈八蛇矛】。` | — |
| 丈八蛇矛 | `<H>\CardPlayDispatcher.java:682` | `请先指定【丈八蛇矛】的目标！` | — |
| 丈八蛇矛 | `<H>\CardPlayDispatcher.java:687` | `目标超出攻击范围！` | — |
| 青釭剑 | `<H>\CardPlayDispatcher.java:381` | `★ %s 装备了 【%s】%s` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:382`，`targets` 空串 |
| 青釭剑 | `<H>\CombatResolver.java:35` | 无专属文案；`ignoreArmor = true` 使藤甲/仁王盾/八卦阵文案全部不出现 | — |
| 贯石斧 | `<H>\CardPlayDispatcher.java:381` | `★ %s 装备了 【%s】%s` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:382`，`targets` 空串 |
| 贯石斧 | `<H>\CombatResolver.java:99` | `🪓 %s 发动【贯石斧】，弃两张牌强制命中！` | — |
| 贯石斧 | `<H>\CombatResolver.java:91-92` | 询问提示：`【贯石斧】是否弃置两张手牌令此【杀】依然生效？请勾选两张牌后点确定（放弃点 PASS）:` | `ASK_RESPONSE`（非广播） |
| 八卦阵 | `<H>\CardPlayDispatcher.java:381` | `★ %s 装备了 【%s】%s` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:382`，`targets` 空串 |
| 八卦阵 | `<H>\CombatResolver.java:261` | `🔮 %s 的【八卦阵】判定：%s → %s` | `SHOW_JUDGE_RESULT` @`<H>\CombatResolver.java:265-273`，7 段，第 2 段固定 `八卦阵`，第 7 段为 `红色 → 视为打出一张【闪】，免疫此【杀】` / `黑色 → 判定失败，需要自行打出一张【闪】` |
| 仁王盾 | `<H>\CardPlayDispatcher.java:381` | `★ %s 装备了 【%s】%s` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:382`，`targets` 空串 |
| 仁王盾 | `<H>\CombatResolver.java:45` | `🛡 %s 的【仁王盾】使黑色%s无效！` | — |
| 白银狮子 | `<H>\CardPlayDispatcher.java:381` | `★ %s 装备了 【%s】%s` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:382`，`targets` 空串 |
| 白银狮子 | `<H>\DamageResolver.java:56` | `%s 的【白银狮子】生效，将伤害锁定为 1 点！`（无 emoji） | — |
| 藤甲 | `<H>\CardPlayDispatcher.java:381` | `★ %s 装备了 【%s】%s` | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:382`，`targets` 空串 |
| 藤甲 | `<H>\CombatResolver.java:39` | `🛡 %s 的【藤甲】使普通%s无效！` | — |
| 藤甲 | `<H>\DamageResolver.java:60` | `%s 穿戴【藤甲】，受到火焰伤害 +1！` | — |
| 藤甲 | `<H>\TrickResolver.java:177` | `🛡 %s 的【藤甲】使【南蛮入侵】无效。` | — |
| 藤甲 | `<H>\TrickResolver.java:201` | `🛡 %s 的【藤甲】使【万箭齐发】无效。` | — |
| +1马 | `<H>\CardPlayDispatcher.java:381` | `★ %s 装备了 【%s】%s`（第 3 段 `（距离修正）`，见 `:379-380`） | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:382`，7 段，`targets` 空串 |
| -1马 | `<H>\CardPlayDispatcher.java:381` | `★ %s 装备了 【%s】%s`（第 3 段 `（距离修正）`，见 `:379-380`） | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:382`，7 段，`targets` 空串 |

## D. 30 种牌型覆盖核对

`<M>\CardType.java:5-10` 基本牌 6（杀 SHA、火杀 FIRE_SHA、雷杀 THUNDER_SHA、闪 SHAN、桃 TAO、酒 JIU）→ 本文 B 节；
`:13-23` 非延时锦囊 11（过河拆桥、顺手牵羊、无中生有、决斗、无懈可击、南蛮入侵、万箭齐发、桃园结义、五谷丰登、火攻、铁索连环）→ B 节 7 种（过河/顺手/无中/决斗/无懈/火攻）+ C 节 4 种（南蛮/万箭/桃园/五谷）；
`:26-28` 延时锦囊 3（乐不思蜀、兵粮寸断、闪电）→ C 节；
`:31-40` 装备 10（诸葛连弩、丈八蛇矛、青釭剑、贯石斧、八卦阵、仁王盾、白银狮子、藤甲、+1马、-1马）→ C 节。
合计 6 + 11 + 3 + 10 = 30，逐张均有「触发点 / BROADCAST_MSG 原文 / payload 顺序」三列。

## E. 与牌使用相关的技能替用播报（触发点仍在 CardPlayDispatcher）

| 场景 | 触发点 | BROADCAST_MSG 原文 | payload |
| --- | --- | --- | --- |
| 龙胆：闪当杀 | `<H>\CardPlayDispatcher.java:274` | `【龙胆】%s 消耗 1 点蓄力，将 %s 当【杀】对 %s 使用！` | 不发 `CARD_PLAYED` |
| 武圣：任意牌当杀 | `<H>\CardPlayDispatcher.java:768` | `【武圣】%s 将 %s 当【杀】对 %s 使用！` | 不发 `CARD_PLAYED` |
| 武圣②：摸牌 | `<H>\CardPlayDispatcher.java:777` | `【武圣】%s 对指定目标使用【杀】，摸一张牌。` | — |
| 乱击：两张牌当万箭 | `<H>\CardPlayDispatcher.java:802` | `【乱击】%s 将两张手牌当【万箭齐发】使用！` | 不发 `CARD_PLAYED` |
| 国色：♦牌当乐不思蜀 | `<H>\CardPlayDispatcher.java:898` | `【国色】%s 将 %s 当【乐不思蜀】置于 %s 的判定区。` | 不发 `CARD_PLAYED` |
| 国色：弃置判定区乐 | `<H>\CardPlayDispatcher.java:921` | `【国色】%s 弃置了 %s 判定区的【乐不思蜀】并摸一张牌。` | — |
| 乡害：装备当酒 | `<H>\CardPlayDispatcher.java:368` | 复用 `🍶 %s 使用%s，本回合下一张【杀】伤害 +1。`（%2 = `【乡害·酒】`） | `CARD_PLAYED` @`<H>\CardPlayDispatcher.java:526` |
| 装备替换 | `G:\desk\Three_Kingdom\src\main\java\com\threekingdom\model\Player.java:398-404` | 旧装备被直接弃置，**无任何播报** | 仅下一次 `CARD_FLOW` 体现数量变化 |

