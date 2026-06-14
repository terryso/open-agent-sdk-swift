---
name: polyv-live-cli
description: 管理保利威直播服务，包括频道管理、推流操作、商品管理、优惠券、回放、文档和统计数据。当用户需要管理直播频道、配置推流设置、管理商品、处理优惠券、查看直播数据或管理回放录像时使用。
allowed-tools: Bash(npx polyv-live-cli@latest:*)
---

# 保利威直播 CLI

## 执行前验证

在执行任何 CLI 命令之前，必须先验证账号认证状态。

### 1. 检测认证状态

```bash
npx polyv-live-cli@latest account list
```

### 2. 配置认证（如需要）

如果用户未配置认证，引导用户提供 AppID 和 AppSecret：

```
请提供你的保利威 AppID 和 AppSecret：
- 访问 https://www.polyv.net/ 后台获取
- 路径：云直播 -> 设置 -> 开发者信息
```

然后用用户提供的凭据配置：

```bash
npx polyv-live-cli@latest account add <名称> --app-id <appId> --app-secret <appSecret>
npx polyv-live-cli@latest account set-default <名称>
```

### 3. 验证配置成功

```bash
npx polyv-live-cli@latest channel list
```

## 快速开始

```bash
# 添加账号凭证
npx polyv-live-cli@latest account add myaccount --app-id <id> --app-secret <secret>

# 切换账号
npx polyv-live-cli@latest use myaccount

# 创建频道
npx polyv-live-cli@latest channel create -n "我的直播"

# 获取推流密钥（用于OBS）
npx polyv-live-cli@latest stream get-key -c <channelId>

# 开始直播
npx polyv-live-cli@latest stream start -c <channelId>

# 监控直播状态
npx polyv-live-cli@latest stream status -c <channelId> -w
```

## 身份认证

```bash
# 账号管理
npx polyv-live-cli@latest account add <名称> --app-id <id> --app-secret <secret>
npx polyv-live-cli@latest account list
npx polyv-live-cli@latest account set-default <名称>
npx polyv-live-cli@latest account remove <名称>

# 切换当前会话账号
npx polyv-live-cli@latest use <名称>

# 或使用内联凭证
npx polyv-live-cli@latest channel list --appId <id> --appSecret <secret>
npx polyv-live-cli@latest channel list -a <账号名称>
```

## 频道命令

```bash
# 增删改查操作
npx polyv-live-cli@latest channel create -n <名称> [-d <描述>] [--scene <场景类型>]
npx polyv-live-cli@latest channel list [-P <页码>] [-l <数量>] [--keyword <关键词>]
npx polyv-live-cli@latest channel get -c <频道ID>
npx polyv-live-cli@latest channel update -c <频道ID> [-n <名称>] [-d <描述>]
npx polyv-live-cli@latest channel delete -c <频道ID> [-f]
npx polyv-live-cli@latest channel batch-delete --channelIds <id1> <id2> ...

# 场景类型: topclass(大班课,默认) | alone(活动营销) | seminar(研讨会) | train(企业培训) | double(双师课,需开通) | guide(导播,需开通)
# 模板: ppt(三分屏-横屏,默认) | portrait_ppt(三分屏-竖屏) | alone(纯视频-横屏) | portrait_alone(纯视频-竖屏) | topclass(纯视频极速-横屏) | portrait_topclass(纯视频极速-竖屏) | seminar(研讨会)
```

## 推流命令

```bash
# 推流操作
npx polyv-live-cli@latest stream get-key -c <频道ID>        # 获取RTMP地址和推流密钥
npx polyv-live-cli@latest stream start -c <频道ID>          # 开始直播
npx polyv-live-cli@latest stream stop -c <频道ID>           # 结束直播
npx polyv-live-cli@latest stream status -c <频道ID> [-w]    # 查看状态（-w持续监控）
npx polyv-live-cli@latest stream push -c <频道ID> -f <文件> # 推送视频文件
npx polyv-live-cli@latest stream verify -c <频道ID> [-d 60] # 直播质量验证
npx polyv-live-cli@latest stream monitor -c <频道ID> [-r 5] # 实时监控面板
```

## 商品命令

```bash
# 商品管理
npx polyv-live-cli@latest product list -c <频道ID>
npx polyv-live-cli@latest product add -c <频道ID> --name <名称> --price <价格>
npx polyv-live-cli@latest product get -c <频道ID> -p <商品ID>
npx polyv-live-cli@latest product update -c <频道ID> -p <商品ID> [--name <名称>]
npx polyv-live-cli@latest product delete -c <频道ID> -p <商品ID>
```

## 优惠券命令

```bash
# 优惠券操作
npx polyv-live-cli@latest coupon add -c <频道ID> --name <名称> --type <类型> --discount <金额>
npx polyv-live-cli@latest coupon list -c <频道ID> [--status enabled|disabled]
npx polyv-live-cli@latest coupon delete -c <频道ID> --coupon-ids <id1> <id2>

# 优惠券类型: discount(折扣券), reduction(满减券)
```

## 回放命令

```bash
# 回放管理
npx polyv-live-cli@latest playback list -c <频道ID>
npx polyv-live-cli@latest playback get -c <频道ID> --video-id <回放ID>
npx polyv-live-cli@latest playback delete -c <频道ID> --video-id <回放ID>
npx polyv-live-cli@latest playback merge -c <频道ID> --file-ids <id1,id2,id3>
```

## 录制设置命令

```bash
# 回放设置管理
npx polyv-live-cli@latest record setting get -c <频道ID>
npx polyv-live-cli@latest record setting set -c <频道ID> [--playback-enabled Y|N] [--type single|list] [--origin playback|vod|record]

# 录制转存
npx polyv-live-cli@latest record convert -c <频道ID> --file-name <文件名> [--session-id <场次ID>] [--async]
npx polyv-live-cli@latest record set-default -c <频道ID> --video-id <视频ID> [--list-type playback|vod]

# origin 类型: playback(回放列表), vod(点播列表), record(录制文件)
# type 类型: single(单个回放), list(列表回放)
```

## 场次命令

```bash
# 场次管理
npx polyv-live-cli@latest session list [-c <频道ID>] [--page <页码>] [--page-size <数量>]
npx polyv-live-cli@latest session get -c <频道ID> --session-id <场次ID>

# 状态值: unStart(未开始), live(直播中), end(已结束), playback(回放中), expired(已过期)
```

## 文档命令

```bash
# 文档管理
npx polyv-live-cli@latest document list -c <频道ID> [--status <状态>] [--page <页码>] [--page-size <数量>]
npx polyv-live-cli@latest document upload -c <频道ID> --url <文件URL> [--type common|animate] [--doc-name <名称>]
npx polyv-live-cli@latest document delete -c <频道ID> --file-id <文档ID> [--type old|new] [--force]
npx polyv-live-cli@latest document status -c <频道ID> --file-id <文档ID>

# 状态值: normal, waitUpload, failUpload, waitConvert, failConvert
# 类型: common(普通转换), animate(动效转换)
```

## 统计命令

```bash
# 查看每日观看统计
npx polyv-live-cli@latest statistics view -c <频道ID> --start-day 2024-01-01 --end-day 2024-01-31

# 查看历史并发数据
npx polyv-live-cli@latest statistics concurrency -c <频道ID> --start-date 2024-01-01 --end-date 2024-01-31

# 查看历史最高并发人数
npx polyv-live-cli@latest statistics max-concurrent -c <频道ID> --start-time 1704067200000 --end-time 1735689600000

# 查看观众统计
npx polyv-live-cli@latest statistics audience device -c <频道ID>    # 设备分布
npx polyv-live-cli@latest statistics audience region -c <频道ID>    # 地区分布

# 导出统计数据
npx polyv-live-cli@latest statistics export -c <频道ID> -f csv -o report.csv
```

## 播放器命令

```bash
# 播放器配置
npx polyv-live-cli@latest player config get -c <频道ID>
npx polyv-live-cli@latest player config update -c <频道ID> [--autoplay] [--logo <url>]
```

## 场景初始化

```bash
# 预设场景
npx polyv-live-cli@latest setup --list                    # 列出可用场景
npx polyv-live-cli@latest setup e-commerce                # 电商直播场景
npx polyv-live-cli@latest setup education                 # 在线教育场景
```

## 监控命令

```bash
# 直播监控面板
npx polyv-live-cli@latest monitor start -c <频道ID>
npx polyv-live-cli@latest monitor stop
```

## 聊天消息命令

```bash
# 发送管理员消息
npx polyv-live-cli@latest chat send -c <频道ID> -m <文本消息>
npx polyv-live-cli@latest chat send -c <频道ID> -i <图片URL>
npx polyv-live-cli@latest chat send -c <频道ID> -m <消息> -n <昵称> -a <角色>

# 查看聊天历史
npx polyv-live-cli@latest chat list -c <频道ID>
npx polyv-live-cli@latest chat list -c <频道ID> --page <页码> --size <数量>
npx polyv-live-cli@latest chat list -c <频道ID> --start-day <开始日期> --end-day <结束日期>

# 删除消息
npx polyv-live-cli@latest chat delete -c <频道ID> -m <消息ID>
npx polyv-live-cli@latest chat delete -c <频道ID> --clear  # 清空所有消息
```

## 禁言踢人命令 (Story 11-2)

```bash
# 禁言用户（频道级别）
npx polyv-live-cli@latest chat ban -c <频道ID> -u <用户ID1,用户ID2>
npx polyv-live-cli@latest chat ban -c <频道ID> -u <用户ID> -o json

# 全局禁言（账号级别）
npx polyv-live-cli@latest chat ban -u <用户ID1,用户ID2> --global

# 解除禁言
npx polyv-live-cli@latest chat unban -c <频道ID> -u <用户ID1,用户ID2>
npx polyv-live-cli@latest chat unban -u <用户ID1,用户ID2> --global

# 踢人（频道级别）
npx polyv-live-cli@latest chat kick -c <频道ID> -v <观众ID1,观众ID2> -n <昵称1,昵称2>
npx polyv-live-cli@latest chat kick -c <频道ID> -v <观众ID> -o json

# 全局踢人（账号级别）
npx polyv-live-cli@latest chat kick -v <观众ID1> -n <昵称1> --global

# 解除踢人
npx polyv-live-cli@latest chat unkick -c <频道ID> -v <观众ID1> -n <昵称1>
npx polyv-live-cli@latest chat unkick -v <观众ID1> --global

# 查看禁言列表
npx polyv-live-cli@latest chat banned list -c <频道ID> --type userId  # 禁言用户列表
npx polyv-live-cli@latest chat banned list -c <频道ID> --type ip      # 禁言IP列表
npx polyv-live-cli@latest chat banned list -c <频道ID> --type badword # 禁言词列表

# 查看踢人列表
npx polyv-live-cli@latest chat kicked list -c <频道ID>
npx polyv-live-cli@latest chat kicked list -c <频道ID> -o json
```

## 签到管理命令 (Story 11-3)

```bash
# 发起签到
npx polyv-live-cli@latest checkin start -c <频道ID>
npx polyv-live-cli@latest checkin start -c <频道ID> --limit-time 30          # 设置签到时长30秒
npx polyv-live-cli@latest checkin start -c <频道ID> --delay-time 1700734800000  # 定时签到
npx polyv-live-cli@latest checkin start -c <频道ID> --message "请签到"       # 自定义签到提示语
npx polyv-live-cli@latest checkin start -c <频道ID> --force                  # 强制签到模式

# 查询签到成功记录
npx polyv-live-cli@latest checkin list -c <频道ID>
npx polyv-live-cli@latest checkin list -c <频道ID> --page 1 --size 20        # 分页查询
npx polyv-live-cli@latest checkin list -c <频道ID> --date 2024-01-15         # 按日期筛选
npx polyv-live-cli@latest checkin list -c <频道ID> --session-id <场次ID>     # 按场次筛选

# 查询签到详情（包括已签到和未签到）
npx polyv-live-cli@latest checkin result -c <频道ID> --checkin-id <签到ID>
npx polyv-live-cli@latest checkin result -c <频道ID> --checkin-id <签到ID> -o json

# 查询签到发起记录（按时间范围）
npx polyv-live-cli@latest checkin sessions -c <频道ID>
npx polyv-live-cli@latest checkin sessions -c <频道ID> --start-date 2024-01-01 --end-date 2024-01-31
npx polyv-live-cli@latest checkin sessions -c <频道ID> -o json
```

## 问答管理命令 (Story 11-4)

```bash
# 发送问答卡（答题卡）
npx polyv-live-cli@latest qa send -c <频道ID> --question-id <问题ID>
npx polyv-live-cli@latest qa send -c <频道ID> --question-id <问题ID> --duration 30      # 设置答题时长30秒
npx polyv-live-cli@latest qa send -c <频道ID> --question-id <问题ID> -o json            # JSON格式输出

# 查询问答卡列表
npx polyv-live-cli@latest qa list -c <频道ID>
npx polyv-live-cli@latest qa list -c <频道ID> -o json                        # JSON格式输出

# 停止问答卡
npx polyv-live-cli@latest qa stop -c <频道ID> --question-id <问题ID>
npx polyv-live-cli@latest qa stop -c <频道ID> --question-id <问题ID> -o json            # JSON格式输出（含统计数据）
```

## 问卷管理命令 (Story 11-4)

```bash
# 创建问卷
npx polyv-live-cli@latest questionnaire create -c <频道ID> --title <问卷标题> --questions '<JSON数组>'
npx polyv-live-cli@latest questionnaire create -c 3151318 --title "满意度调查" --questions '[{"name":"性别","type":"R","options":["男","女"],"required":"Y"}]'

# 问卷题型类型: R=单选, C=多选, Q=填空, J=判断, X=评分
# 创建带自定义ID的问卷
npx polyv-live-cli@latest questionnaire create -c <频道ID> --title <标题> --questions '<JSON>' --custom-questionnaire-id <自定义ID>

# 查询问卷列表
npx polyv-live-cli@latest questionnaire list -c <频道ID>
npx polyv-live-cli@latest questionnaire list -c <频道ID> --page 1 --size 20  # 分页查询
npx polyv-live-cli@latest questionnaire list -c <频道ID> --session-id <场次ID>  # 按场次筛选
npx polyv-live-cli@latest questionnaire list -c <频道ID> --start-date 2024-01-01 --end-date 2024-01-31  # 日期范围

# 获取问卷详情
npx polyv-live-cli@latest questionnaire detail -c <频道ID> --questionnaire-id <问卷ID>
npx polyv-live-cli@latest questionnaire detail -c <频道ID> --questionnaire-id <问卷ID> -o json  # JSON格式输出
```

## 抽奖管理命令 (Story 11-5)

```bash
# 创建抽奖活动
npx polyv-live-cli@latest lottery create -c <频道ID> --name <抽奖名称> --type <类型> --amount <中奖人数> --prize <奖品名称>
npx polyv-live-cli@latest lottery create -c 3151318 --name "幸运抽奖" --type none --amount 3 --prize "神秘礼品"  # 无条件抽奖
npx polyv-live-cli@latest lottery create -c 3151318 --name "邀请抽奖" --type invite --amount 5 --prize "优惠券" --invite-num 3  # 邀请抽奖
npx polyv-live-cli@latest lottery create -c 3151318 --name "时长抽奖" --type duration --amount 2 --prize "红包" --duration 10  # 观看时长抽奖

# 抽奖类型: none=无条件, invite=邀请好友, duration=观看时长, comment=发表评论, question=回答问题

# 查询抽奖活动列表
npx polyv-live-cli@latest lottery list -c <频道ID>
npx polyv-live-cli@latest lottery list -c <频道ID> --page 1 --size 20  # 分页查询
npx polyv-live-cli@latest lottery list -c <频道ID> -o json  # JSON格式输出

# 获取抽奖活动详情
npx polyv-live-cli@latest lottery get -c <频道ID> --id <抽奖活动ID>

# 更新抽奖活动
npx polyv-live-cli@latest lottery update -c <频道ID> --id <抽奖活动ID> --name <新名称> --amount <新人数>

# 删除抽奖活动
npx polyv-live-cli@latest lottery delete -c <频道ID> --id <抽奖活动ID>

# 查询中奖用户
npx polyv-live-cli@latest lottery winners -c <频道ID> --lottery-id <抽奖ID>
npx polyv-live-cli@latest lottery winners -c <频道ID> --lottery-id <抽奖ID> --page 1 --limit 20  # 分页查询

# 查询抽奖记录
npx polyv-live-cli@latest lottery records -c <频道ID>
npx polyv-live-cli@latest lottery records -c <频道ID> --session-id <场次ID>  # 按场次筛选
npx polyv-live-cli@latest lottery records -c <频道ID> --start-time <时间戳> --end-time <时间戳>  # 按时间范围
```

## 打赏管理命令 (Story 11-6)

```bash
# 获取打赏配置
npx polyv-live-cli@latest donate config get -c <频道ID>
npx polyv-live-cli@latest donate config get -c 3151318 -o json  # JSON格式输出

# 更新打赏配置
npx polyv-live-cli@latest donate config update -c <频道ID> --cash-enabled Y  # 启用现金打赏
npx polyv-live-cli@latest donate config update -c <频道ID> --gift-enabled Y  # 启用礼物打赏
npx polyv-live-cli@latest donate config update -c <频道ID> --tips "感谢支持!"  # 设置打赏提示语
npx polyv-live-cli@latest donate config update -c <频道ID> --amounts "0.88,6.66,8.88,18.88"  # 设置打赏金额

# 查询打赏记录
npx polyv-live-cli@latest donate list -c <频道ID> --start <开始时间戳> --end <结束时间戳>
npx polyv-live-cli@latest donate list -c 3151318 --start 1615772426000 --end 1615858826000
npx polyv-live-cli@latest donate list -c 3151318 --start 1615772426000 --end 1615858826000 --page 2 --size 20  # 分页
npx polyv-live-cli@latest donate list -c 3151318 --start 1615772426000 --end 1615858826000 -o json  # JSON格式
```

## 观众信息查询命令 (Story 12-1)

```bash
# 获取单个观众详情
npx polyv-live-cli@latest viewer get -v <观众ID>
npx polyv-live-cli@latest viewer get -v "2_v378gn997yovtl3p8h77db9e224t6hg9" -o json  # JSON格式输出

# 列出观众列表
npx polyv-live-cli@latest viewer list
npx polyv-live-cli@latest viewer list --page 1 --size 20  # 分页查询
npx polyv-live-cli@latest viewer list --source IMPORT      # 按来源过滤（IMPORT/WX/MOBILE）
npx polyv-live-cli@latest viewer list --mobile "13800138000"  # 按手机号过滤
npx polyv-live-cli@latest viewer list --email "user@example.com"  # 按邮箱过滤
npx polyv-live-cli@latest viewer list --area "北京"  # 按地址过滤
npx polyv-live-cli@latest viewer list --source WX -o json  # JSON格式输出
```

## 观众标签管理命令 (Story 12-2)

```bash
# 列出所有标签
npx polyv-live-cli@latest viewer tag list

# 搜索标签
npx polyv-live-cli@latest viewer tag list --keyword "VIP"

# 分页查询
npx polyv-live-cli@latest viewer tag list --page 1 --size 20

# JSON格式输出
npx polyv-live-cli@latest viewer tag list -o json

# 为观众添加标签（单个观众+单个标签）
npx polyv-live-cli@latest viewer tag add -v "viewer1" -l 1

# 为观众添加多个标签
npx polyv-live-cli@latest viewer tag add -v "viewer1" -l 1,2,3

# 批量为多个观众添加标签
npx polyv-live-cli@latest viewer tag add -v "viewer1,viewer2,viewer3" -l 1,2

# JSON格式输出
npx polyv-live-cli@latest viewer tag add -v "viewer1" -l 1 -o json

# 移除观众的标签（单个观众+单个标签）
npx polyv-live-cli@latest viewer tag remove -v "viewer1" -l 1

# 移除观众的多个标签
npx polyv-live-cli@latest viewer tag remove -v "viewer1" -l 1,2,3

# 批量移除多个观众的标签
npx polyv-live-cli@latest viewer tag remove -v "viewer1,viewer2" -l 1,2

# JSON格式输出
npx polyv-live-cli@latest viewer tag remove -v "viewer1" -l 1 -o json
```

## 观看条件配置命令 (Story 12-3)

```bash
# 获取观看条件配置
npx polyv-live-cli@latest watch-condition get                  # 获取全局设置
npx polyv-live-cli@latest watch-condition get --channel-id <频道ID>  # 获取频道设置
npx polyv-live-cli@latest watch-condition get --channel-id 3151318 -o json  # JSON格式输出

# 简单设置：关闭观看条件（公开观看）
npx polyv-live-cli@latest watch-condition set --channel-id <频道ID> --rank 1 --auth-type none --enabled Y

# 简单设置：密码观看
npx polyv-live-cli@latest watch-condition set --channel-id <频道ID> --rank 1 --auth-type code --enabled Y --auth-code "abc123"

# 简单设置：付费观看（价格单位：元）
npx polyv-live-cli@latest watch-condition set --channel-id <频道ID> --rank 1 --auth-type pay --enabled Y --price 99.9

# 复杂设置：使用 JSON 配置文件（支持多个条件和完整参数）
npx polyv-live-cli@latest watch-condition set --channel-id <频道ID> --config ./watch-condition.json

# 设置全局观看条件（不传频道ID）
npx polyv-live-cli@latest watch-condition set --rank 1 --auth-type none --enabled N

# 认证类型: none=无限制, code=密码观看, pay=付费观看, phone=白名单观看, info=登记观看, custom=自定义授权, external=外部授权, direct=独立授权
# 条件级别: rank 1=主要条件, rank 2=次要条件
# 启用状态: enabled Y=启用, N=禁用
```

JSON 配置文件格式示例 (`watch-condition.json`):

```json
{
  "authSettings": [
    {
      "rank": 1,
      "enabled": "Y",
      "authType": "code",
      "authCode": "abc123"
    },
    {
      "rank": 2,
      "enabled": "N"
    }
  ]
}
```

## 白名单管理命令 (Story 12-4)

```bash
# 列出白名单
npx polyv-live-cli@latest whitelist list --rank 1                          # 获取全局白名单
npx polyv-live-cli@latest whitelist list --channel-id <频道ID> --rank 1    # 获取频道白名单
npx polyv-live-cli@latest whitelist list --channel-id 3151318 --rank 1 --page 1 --page-size 20  # 分页
npx polyv-live-cli@latest whitelist list --channel-id 3151318 --rank 1 --keyword "张三"  # 搜索
npx polyv-live-cli@latest whitelist list --channel-id 3151318 --rank 1 -o json  # JSON格式输出

# 添加白名单
npx polyv-live-cli@latest whitelist add --rank 1 --code "13800138000" --name "张三"  # 全局白名单
npx polyv-live-cli@latest whitelist add --channel-id <频道ID> --rank 1 --code "13800138000" --name "张三"  # 频道白名单
npx polyv-live-cli@latest whitelist add --rank 1 --code "13800138000" -o json  # JSON格式输出

# 更新白名单
npx polyv-live-cli@latest whitelist update --rank 1 --old-code "13800138000" --code "13900139000" --name "李四"  # 全局
npx polyv-live-cli@latest whitelist update --channel-id <频道ID> --rank 1 --old-code "13800138000" --code "13900139000" --name "李四"  # 频道
npx polyv-live-cli@latest whitelist update --rank 1 --old-code "13800138000" --code "13900139000" -o json  # JSON格式输出

# 删除白名单
npx polyv-live-cli@latest whitelist remove --rank 1 --codes "13800138000"  # 删除单个（全局）
npx polyv-live-cli@latest whitelist remove --channel-id <频道ID> --rank 1 --codes "13800138000,13900139000"  # 批量删除
npx polyv-live-cli@latest whitelist remove --channel-id <频道ID> --rank 1 --clear  # 清空所有白名单
npx polyv-live-cli@latest whitelist remove --rank 1 --codes "13800138000" -o json  # JSON格式输出

# 条件级别: rank 1=主要条件, rank 2=次要条件
# 不传 --channel-id 为全局设置，传 --channel-id 为频道级别设置
```

## 平台账号信息管理命令 (Story 13-1)

```bash
# 获取账号基本信息（用户ID、邮箱、频道数等）
npx polyv-live-cli@latest platform get
npx polyv-live-cli@latest platform get -o json  # JSON格式输出

# 获取账号开关配置（全局设置、认证、录制等开关状态）
npx polyv-live-cli@latest platform switch get
npx polyv-live-cli@latest platform switch get -o json  # JSON格式输出

# 更新账号开关配置
npx polyv-live-cli@latest platform switch update --param authEnabled --enabled Y      # 启用认证
npx polyv-live-cli@latest platform switch update --param recordEnabled --enabled N    # 禁用录制
npx polyv-live-cli@latest platform switch update --param authEnabled --enabled Y -o json  # JSON格式输出

# 可用开关参数:
# - globalSettingEnabled: 全局设置开关
# - authEnabled: 认证开关
# - recordEnabled: 录制开关
# - playbackEnabled: 回放开关
# - danmuEnabled: 弹幕开关
```

## 回调设置管理命令 (Story 13-2)

```bash
# 获取回调设置（回调URL和启用状态）
npx polyv-live-cli@latest platform callback get
npx polyv-live-cli@latest platform callback get -o json  # JSON格式输出

# 更新回调设置
npx polyv-live-cli@latest platform callback update --url https://example.com/callback  # 更新回调URL
npx polyv-live-cli@latest platform callback update --enabled Y                          # 启用回调
npx polyv-live-cli@latest platform callback update --url https://example.com/callback --enabled Y  # 同时更新
npx polyv-live-cli@latest platform callback update --url https://example.com/callback -o json  # JSON格式输出
```

### 全局频道设置管理

管理账号级别的全局频道设置，包括并发人数、转码、打赏等功能开关。

```bash
# 获取全局频道设置
npx polyv-live-cli@latest platform setting get
npx polyv-live-cli@latest platform setting get -o json  # JSON格式输出

# 更新全局频道设置
npx polyv-live-cli@latest platform setting update --channel-concurrences-enabled Y  # 启用最大并发人数
npx polyv-live-cli@latest platform setting update --timely-convert-enabled N         # 禁用自动转码
npx polyv-live-cli@latest platform setting update --donate-enabled Y                 # 启用打赏功能
npx polyv-live-cli@latest platform setting update --cover-img-type contain           # 设置封面类型

# 同时更新多个设置
npx polyv-live-cli@latest platform setting update \
  --channel-concurrences-enabled Y \
  --timely-convert-enabled Y \
  --donate-enabled N \
  -o json  # JSON格式输出
```

#### 可用参数

| 参数 | 说明 | 值 |
|------|------|------|
| --channel-concurrences-enabled | 最大并发观看人数开关 | Y/N |
| --timely-convert-enabled | 自动转码开关 | Y/N |
| --donate-enabled | 打赏功能开关 | Y/N |
| --rebirth-auto-upload-enabled | 转存自动上传PPT | Y/N |
| --rebirth-auto-convert-enabled | 转存自动转码 | Y/N |
| --ppt-covered-enabled | PPT全屏开关 | Y/N |
| --cover-img-type | 封面图片类型 | contain/cover |
| --test-mode-button-enabled | 测试模式按钮 | Y/N |

## 转播管理命令 (Story 14-3)

```bash
# 批量创建转播频道
npx polyv-live-cli@latest transmit create -c <频道ID> --names "频道1,频道2,频道3"
npx polyv-live-cli@latest transmit create -c 3151318 --names "转播1,转播2,转播3" -o json

# 获取转播关联列表
npx polyv-live-cli@latest transmit list -c <频道ID>
npx polyv-live-cli@latest transmit list -c 3151318 -o json

# 最多支持一次创建100个转播频道
# -o table 为默认表格格式, -o json 为JSON格式输出
```

## 卡片推送命令 (Story 14-2)

```bash
# 列出卡片配置
npx polyv-live-cli@latest card-push list -c <频道ID>
npx polyv-live-cli@latest card-push list -c 3151318 -o json

# 创建卡片配置
npx polyv-live-cli@latest card-push create -c <频道ID> --image-type <类型> --title <标题> --link <链接> --duration <秒数> --show-condition PUSH|WATCH
npx polyv-live-cli@latest card-push create -c 3151318 --image-type giftbox --title "限时优惠" --link "https://example.com" --duration 10 --show-condition PUSH

# 定时弹出卡片（观看时长触发）
npx polyv-live-cli@latest card-push create -c 3151318 --image-type redpack --title "新手红包" --link "https://example.com" --duration 15 --show-condition WATCH --condition-value 30 --condition-unit SECONDS

# 更新卡片配置
npx polyv-live-cli@latest card-push update -c <频道ID> --card-push-id <卡片ID> --title <新标题>
npx polyv-live-cli@latest card-push update -c 3151318 --card-push-id 123 --duration 20

# 推送卡片
npx polyv-live-cli@latest card-push push -c <频道ID> --card-push-id <卡片ID>

# 取消推送
npx polyv-live-cli@latest card-push cancel -c <频道ID> --card-push-id <卡片ID>

# 删除卡片配置
npx polyv-live-cli@latest card-push delete -c <频道ID> --card-push-id <卡片ID>

# image-type: giftbox(礼盒), redpack(红包), custom(自定义)
# show-condition: PUSH(手动推送), WATCH(观看时长触发)
# card-type: common(普通), qrCode(二维码)
```

## 输出格式

大多数命令支持 `-o table`（默认表格格式）或 `-o json`（JSON格式，便于程序化处理）。

```bash
npx polyv-live-cli@latest channel list -o json
npx polyv-live-cli@latest stream status -c <频道ID> -o json
```

## 全局选项

```bash
--appId <id>           # 保利威应用ID
--appSecret <secret>   # 保利威应用密钥
--userId <id>          # 保利威用户ID（可选）
-a, --account <名称>   # 使用指定账号
--verbose              # 显示详细信息
--debug                # 启用调试模式
--timeout <毫秒>       # API超时时间（默认30000毫秒）
```

## 常用工作流程

### 创建并开始直播

```bash
npx polyv-live-cli@latest use myaccount
npx polyv-live-cli@latest channel create -n "新品发布会" -d "新品展示直播"
# 记住输出的频道ID
npx polyv-live-cli@latest stream get-key -c 3151318
# 在OBS中使用RTMP地址和推流密钥
npx polyv-live-cli@latest stream start -c 3151318
npx polyv-live-cli@latest stream status -c 3151318 -w
```

### 初始化电商直播场景

```bash
npx polyv-live-cli@latest setup e-commerce
# 自动创建带商品预配置的频道
```

### 监控直播质量

```bash
npx polyv-live-cli@latest stream verify -c 3151318 -d 120 -i 5
npx polyv-live-cli@latest stream monitor -c 3151318 -r 3 --alerts
```

## 详细文档

* **身份认证配置** [references/authentication.md](references/authentication.md)
* **频道管理** [references/channel-management.md](references/channel-management.md)
* **推流操作** [references/streaming.md](references/streaming.md)
* **商品管理** [references/products.md](references/products.md)
* **优惠券管理** [references/coupons.md](references/coupons.md)
* **回放管理** [references/playback.md](references/playback.md)
* **录制设置** [references/record-settings.md](references/record-settings.md)
* **场次管理** [references/session-management.md](references/session-management.md)
* **文档管理** [references/documents.md](references/documents.md)
* **聊天消息管理** [references/chat-management.md](references/chat-management.md)
* **签到管理** [references/checkin.md](references/checkin.md)
* **问答问卷管理** [references/qa-questionnaire.md](references/qa-questionnaire.md)
* **抽奖管理** [references/lottery.md](references/lottery.md)
* **打赏管理** [references/donate.md](references/donate.md)
* **观众信息查询** [references/viewer.md](references/viewer.md)
* **观众标签管理** [references/viewer-management.md](references/viewer-management.md)
* **观看条件配置** [references/watch-condition.md](references/watch-condition.md)
* **白名单管理** [references/whitelist.md](references/whitelist.md)
* **平台账号信息管理** [references/platform.md](references/platform.md)
* **卡片推送管理** [references/card-push.md](references/card-push.md)
* **转播管理** [references/transmit.md](references/transmit.md)
* **播放器配置** [references/player.md](references/player.md)
* **直播监控** [references/monitor.md](references/monitor.md)
* **统计分析** [references/statistics.md](references/statistics.md)
* **场景初始化** [references/scene-setup.md](references/scene-setup.md)

## 联系方式

- 邮箱: support@polyv.net
- 官网: https://www.polyv.net/
- 保利威直播 API 文档: https://help.polyv.net/#/live/api/
- 技术支持: 400-993-9533
