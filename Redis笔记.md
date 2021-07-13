## 六种数据类型

## 事务

相关命令：

> watch, multi, exec, discard

### 事务

### 事务回滚

### 事务监控

在 [Redis](http://m.biancheng.net/redis/) 中使用 `watch` 命令可以决定事务是执行还是回滚。一般而言，可以在 `multi` 命令之前使用 `watch` 命令监控某些键值对，然后使用 `multi` 命令开启事务，执行各类对[数据结构](http://m.biancheng.net/data_structure/)进行操作的命令，这个时候这些命令就会进入队列。

当 Redis 使用 `exec` 命令执行事务的时候，它首先会去比对被 `watch` 命令所监控的键值对，如果没有发生变化，那么它会执行事务队列中的命令，提交事务；如果发生变化，那么它不会执行任何事务中的命令，而去事务回滚。无论事务是否回滚，Redis 都会去取消执行事务前的 `watch` 命令，这个过程如下所示。

![Redis执行事务过程](http://m.biancheng.net/uploads/allimg/190724/5-1ZH4122J5538.png)

`watch`必须在`multi`外使用。

### pipeline

Redis 的流水线（pipelined）技术就是使用队列批量执行一系列的命令，从而提高系统性能。现实中 Redis 执行读/写速度十分快，而系统的瓶颈往往是在网络通信中的延时。

_在事务中 Redis 也提供了可以批量执行任务的队列，它的性能就比较高，但是使用 multi...exec 事务命令是有系统开销的，因为它会检测对应的锁和序列化命令。_

## 发布订阅

Redis 发布订阅 (pub/sub) 是一种消息通信模式：发送者 (pub) 发送消息，订阅者 (sub) 接收消息。Redis 客户端可以订阅任意数量的频道。

![img](https://www.runoob.com/wp-content/uploads/2014/11/pubsub1.png)

当有新消息通过 PUBLISH 命令发送给频道 channel1 时， 这个消息就会被发送给订阅它的三个客户端：

![img](https://www.runoob.com/wp-content/uploads/2014/11/pubsub2.png)

## 超时回收

Redis可以设置键的超时时间，又因为Redis是操作内存的，所有需要回收机制。

### 给对应的键值设置超时

| 命  令                   | 说  明                   | 备  注                                                       |
| ------------------------ | ------------------------ | ------------------------------------------------------------ |
| persist key              | 持久化 key，取消超时时间 | 移除 key 的超时时间                                          |
| ttl key                  | 査看 key 的超时时间      | 以秒计算，-1 代表没有超时时间，如果不存在 key 或者 key 已经超时则为 -2 |
| expire key seconds       | 设置超时时间戳           | 以秒为单位                                                   |
| expireat key timestamp   | 设置超时时间点           | 用 uninx 时间戳确定                                          |
| pptl key milliseconds    | 查看key的超时时间戳      | 用亳秒计算                                                   |
| pexpire key              | 设置键值超时的时间       | 以亳秒为单位                                                 |
| Pexpireat key stamptimes | 设置超时时间点           | 以亳秒为单位的 uninx 时间戳                                  |

### 回收

当内存不足时 Redis 会触发自动垃圾回收的机制，一般回收超时的键值对。

Redis 提供两种方式回收这些超时键值对，它们是`定时回收`和`惰性回收`。

> 定时回收是指在确定的某个时间触发一段代码，回收超时的键值对。
>
> 惰性回收则是当一个超时的键，被再次用 get 命令访问时，将触发 Redis 将其从内存中清空。

定时回收可以完全回收那些超时的键值对，但是缺点也很明显，如果这些键值对比较多，则 Redis 需要运行较长的时间，从而导致停顿。所以系统设计者一般会选择在没有业务发生的时刻触发 Redis 的定时回收，以便清理超时的键值对。

对于惰性回收而言，它的优势是可以指定回收超时的键值对，它的缺点是要执行一个莫名其妙的 get 操作，或者在某些时候，我们也难以判断哪些键值对已经超时。

无论是定时回收还是惰性回收，都要依据自身的特点去定制策略，如果一个键值对，存储的是数以千万的数据，使用 expire 命令使其到达一个时间超时，然后用 get 命令访问触发其回收，显然会付出停顿代价，这是现实中需要考虑的。

> __如果 key 超时了，Redis 会回收 key 的存储空间吗？__
>
> __不会__。Redis 的 key 超时不会被其自动回收，它只会标识哪些键值对超时了。这样做的一个好处在于，如果一个很大的键值对超时，比如一个列表或者哈希结构，存在数以百万个元素，要对其回收需要很长的时间。如果采用超时回收，则可能产生停顿。坏处也很明显，这些超时的键值对会浪费比较多的空间。

### [回收策略](http://m.biancheng.net/view/4562.html)

在 Redis 的配置文件中，当 Redis 的内存达到规定的最大值时，允许配置 6 种策略中的一种进行淘汰键值，并且将一些键值对进行回收。

| 名称            | 说明                                                         |
| --------------- | ------------------------------------------------------------ |
| volatile-lru    | 采用最近使用最少的淘汰策略，Redis 将回收那些超时的（仅仅是超时的）键值对，也就是它只淘汰那些超时的键值对。 |
| allkeys-lru     | 采用淘汰最少使用的策略，Redis 将对所有的（不仅仅是超时的）键值对采用最近使用最少的淘汰策略。 |
| volatile-random | 采用随机淘汰策略删除超时的（仅仅是超时的）键值对。           |
| allkeys-random  | 采用随机淘汰策略删除所有的（不仅仅是超时的）键值对，这个策略不常用。 |
| volatile-ttl    | 采用删除存活时间最短的键值对策略。                           |
| noeviction      | 根本就不淘汰任何键值对，当内存已满时，如果做读操作，例如 get 命令，它将正常工作，而做写操作，它将返回错误。也就是说，当 Redis 采用这个策略内存达到最大的时候，它就只能读而不能写了。 |

## 脚本

在 [Redis](http://m.biancheng.net/redis/) 的 2.6 以上版本中，除了可以使用命令外，还可以使用 Lua 语言操作 Redis。从前面的命令可以看出 Redis 命令的计算能力并不算很强大，而使用 Lua 语言则在很大程度上弥补了 Redis 的这个不足。

只是在 Redis 中，执行 Lua 语言是原子性的，也就说 Redis 执行 Lua 的时候是不会被中断的，具备原子性，这个特性有助于 Redis 对并发数据一致性的支持。

*Redis 支持两种方法运行脚本，一种是直接输入一些 Lua 语言的程序代码；另外一种是将 Lua 语言编写成文件。*

```lua
EVAL script numkeys key [key ...] arg [arg ...]
```

> eval 代表执行 Lua 语言的命令。
>
> Lua-script 代表 Lua 语言脚本。
>
> key-num 整数代表参数中有多少个 key，需要注意的是 Redis 中 key 是从 1 开始的，如果没有 key 的参数，那么写 0。
>
> [key1key2key3...] 是 key 作为参数传递给 Lua 语言，也可以不填它是 key 的参数，但是需要和 key-num 的个数对应起来。
>
> [value1 value2 value3...] 这些参数传递给 Lua 语言，它们是可填可不填的。

```lua
# 执行lua脚本
EVAL script numkeys key [key ...] arg [arg ...]

# 查看指定的脚本是否已经被保存在缓存当中
SCRIPT EXISTS script [script ...]

# 从脚本缓存中移除所有脚本
SCRIPT FLUSH

# 加载脚本并返回sha-1签名，然后根据签名执行脚本
SCRIPT LOAD script
EVALSHA sha1 numkeys key [key ...] arg [arg ...] 
```
举例：

```lua
# 返回一个字符串，并不需要任何参数，所以 key-num 填写了 0，代表着没有任何 key 参数。
eval "return'hello java'" 0

# 设置一个键值对，可以在 Lua 语言中采用 redis.call(command,key[param1,param2...]) 进行操作
## command 是命令，包括 set、get、del 等
## Key 是被操作的键
## param1,param2...代表给 key 的参数
eval "redis.call('set',KEYS[1],ARGV[1])" 1 lua-key lua-value

# 使用 Redis 缓存脚本的功能，在 Redis 中脚本会通过 SHA-1 签名算法加密脚本，然后返回一个标识字符串，可以通过这个字符串执行加密后的脚本
script load "redis.call('set', KEYS[1], ARGV[1])"  # 返回 7skf7ej24jdy822j295l2gg
evalsha 7skf7ej24jdy822j295l2gg 1 key1 value1
get key1  # 返回 value1
```

终端执行命令：

```bash
redis-cli --eval test.lua key1 key2 , 2 4
```

*这里需要非常注意命令，执行的命令键和参数是使用逗号分隔的，而键之间用空格分开。在本例中 key2 和参数之间是用逗号分隔的，而这个逗号前后的空格是不能省略的，这是要非常注意的地方，一旦左边的空格被省略了，那么 Redis 就会认为“key2,”是一个键，一旦右边的空格被省略了，Redis 就会认为“,2”是一个键。*

## 备份方式

在 [Redis](http://m.biancheng.net/redis/) 中存在两种方式的备份。[参考此处](http://m.biancheng.net/view/4560.html)

* 快照恢复（RDB），通过快照（snapshotting）实现的，它是备份当前瞬间 Redis 在内存中的数据记录。
* AOF，当 Redis 执行写命令后，在一定的条件下将执行过的写命令依次保存在 Redis 的文件中，将来就可以依次执行那些保存的命令恢复 Redis 的数据了。

对于快照备份而言，如果当前 Redis 的数据量大，备份可能造成 Redis 卡顿，但是恢复重启是比较快速的；对于 AOF 备份而言，它只是追加写入命令，所以备份一般不会造成 Redis 卡顿，但是恢复重启要执行更多的命令，备份文件可能也很大，使用者使用的时候要注意。

## 主从复制

### 主从同步的概念

互联网系统一般是以主从架构为基础的，所谓主从架构设计的思路**大概**是：

- 在多台数据服务器中，只有一台主服务器，而主服务器只负责写入数据，不负责让外部程序读取数据。
- 存在多台从服务器，从服务器不写入数据，只负责同步主服务器的数据，并让外部程序读取数据。
- 主服务器在写入数据后，即刻将写入数据的命令发送给从服务器，从而使得主从数据同步。
- 应用程序可以随机读取某一台从服务器的数据，这样就分摊了读数据的压力。
- 当从服务器不能工作的时候，整个系统将不受影响；当主服务器不能工作的时候，可以方便地从从服务器中选举一台来当主服务器。

*每一种数据存储的软件都会根据其自身的特点对上面的这几点思路加以改造，但是万变不离其宗，只要理解了这几点就很好理解 Redis 的复制机制了。*

![主从同步机制](http://m.biancheng.net/uploads/allimg/190725/5-1ZH5133K49E.png)

### 主从配置

对 Redis 进行主从同步的配置分为主机与从机，主机是一台，而从机可以是多台。

**主机**关键的两个配置是 `dir` 和 `dbfilename` 选项，当然必须保证这两个文件是可写的。对于 Redis 的默认配置而言，`dir` 的默认值为“./”，而对于 `dbfilename` 的默认值为“dump.rbd”。

**从机**主要关注`slaveof` 这个配置选项。

*配置文件中的`bind`表示允许访问的机器，所有机器可访问配置“0.0.0.0”。*

### 同步过程

![Redis主从同步](http://m.biancheng.net/uploads/allimg/190725/5-1ZH5134541460.png)

## 哨兵模式

### 哨兵

哨兵是一个可以独立的运行进程。其原理是哨兵通过发送命令，等待 Redis 服务器响应，从而监控运行的多个 Redis 实例。

> 作用：
>
> - 通过发送命令，让 Redis 服务器返回监测其运行状态，包括主服务器和从服务器。
> - 当哨兵监测到 master 宕机，会自动将 slave 切换成 master，然后通过发布订阅模式通知到其他的从服务器，修改配置文件，让它们切换主机。

一个哨兵监控多个服务器也可能出现问题，所以一般会设定多个哨兵。多个哨兵不仅监控各个 Redis 服务器，而且哨兵之间互相监控，看看哨兵们是否还“活”着，如下图。

![多哨兵监控Redis](http://m.biancheng.net/uploads/allimg/190725/5-1ZH5140G1323.png)

一个哨兵任务主服务器不可用，被称为主观下线。当一定数量的哨兵认为主服务器不可用时，某个哨兵会发起投票，决定是否进行failover操作。failover操作成功后，会通过发布订阅方式，让各个哨兵把自己监控的服务器实现切换主机，这个过程被称为客观下线。

### 哨兵搭建

机器分配如下。

| 服务类型 | 是否主服务器 | IP地址         | 端口  |
| -------- | ------------ | -------------- | ----- |
| Redis    | 是           | 192.168.11.128 | 6379  |
| Redis    | 否           | 192.168.11.129 | 6379  |
| Redis    | 否           | 192.168.11.130 | 6379  |
| Sentinel | ——           | 192.168.11.128 | 26379 |
| Sentinel | ——           | 192.168.11.129 | 26379 |
| Sentinel | ——           | 192.168.11.130 | 26379 |

#### 配置redis主从

配置主机的redis.conf文件。

```conf
port 6379
daemonize no

# 使得Redis服务器可以跨网络访问
bind 0.0.0.0

# 设置密码
requiredpass "abcdefg"

protected-mode no
# Generated by CONFIG REWRITE
dir "/home/appadmin/redis"
```

配置从机的redis.conf文件。

```conf
port 6379
daemonize no
bind 0.0.0.0

# 指定主服务器，注意：有关slaveof的配置只是配置从服务器，而主服务器不需要配置
slaveof 192.168.11.128 6379

# 主服务器密码，注意：有关slaveof的配置只是配置从服务器，而主服务器不需要配置
masterauth abcdefg

protected-mode no
# Generated by CONFIG REWRITE
dir "/home/appadmin/redis"
```

#### 配置哨兵

配置 3 个哨兵，每一个哨兵的配置都是一样的，在 Redis 安装目录下可以找到 sentinel.conf 文件，然后对其进行修改。

```conf
# 禁止保护模式
protected-mode no

# 配置监听的主服务器，这里 sentinel monitor 代表监控
# mymaster代表服务器名称，可以自定义
# 192.168.11.128代表监控的主服务器
# 6379代表端口
# 2代表只有两个或者两个以上的烧饼认为主服务器不可用的时候，才会做故障切换操作
sentinel monitor mymaster 192.168.11.128 6379 2

# sentinel auth-pass 定义服务的密码
# mymaster服务名称
# abcdefg Redis服务器密码
sentinel auth-pass mymaster abcdefg
```

哨兵的其它配置。

| 配置项                           | 参数类型                     | 作用                                                         |
| -------------------------------- | ---------------------------- | ------------------------------------------------------------ |
| port                             | 整数                         | 启动哨兵进程端口                                             |
| dir                              | 文件夹目录                   | 哨兵进程服务临时文件夹，默认为 /tmp，要保证有可写入的权限    |
| sentinel down-after-milliseconds | <服务名称><亳秒数（整数）>   | 指定哨兵在监测 Redis 服务时，当 Redis 服务在一个亳秒数内都无 法回答时，单个哨兵认为的主观下线时间，默认为 30000（30秒） |
| sentinel parallel-syncs          | <服务名称><服务器数（整数）> | 指定可以有多少 Redis 服务同步新的主机，一般而言，这个数字越 小同步时间就越长，而越大，则对网络资源要求则越高 |
| sentinel failover-timeout        | <服务名称><亳秒数（整数）>   | 指定在故障切换允许的亳秒数，当超过这个亳秒数的时候，就认为 切换故障失败，默认为 3 分钟 |
| sentinel notification-script     | <服务名称><脚本路径>         | 指定 sentinel 检测到该监控的 redis 实例指向的实例异常时，调用的 报警脚本。该配置项可选，比较常用 |

#### 启动

要注意服务器启动的顺序:

1. 启动主机（192.168.11.128）的 Redis 服务进程
2. 启动从机的服务进程
3. 启动 3 个哨兵的服务进程

```bash
#启动哨兵进程
./redis-sentinel ../sentinel.conf
#启动Redis服务器进程
./redis-server ../redis.conf
```

## Redis 配置

可以通过`config`命令来获取或修改redis配置。格式：

```bash
> CONFIG GET CONFIG_SETTING_NAME
```

举例：

```redis
192.168.101.34:6379> config get loglevel
1) "loglevel"
2) "notice"
192.168.101.34:6379> config get *  # 获取所有配置
```

配置说明：

| 序号 | 配置项                                                       | 说明                                                         |
| :--- | :----------------------------------------------------------- | :----------------------------------------------------------- |
| 1    | `daemonize no`                                               | Redis 默认不是以守护进程的方式运行，可以通过该配置项修改，使用 yes 启用守护进程（Windows 不支持守护线程的配置为 no ） |
| 2    | `pidfile /var/run/redis.pid`                                 | 当 Redis 以守护进程方式运行时，Redis 默认会把 pid 写入 /var/run/redis.pid 文件，可以通过 pidfile 指定 |
| 3    | `port 6379`                                                  | 指定 Redis 监听端口，默认端口为 6379，作者在自己的一篇博文中解释了为什么选用 6379 作为默认端口，因为 6379 在手机按键上 MERZ 对应的号码，而 MERZ 取自意大利歌女 Alessia Merz 的名字 |
| 4    | `bind 127.0.0.1`                                             | 绑定的主机地址                                               |
| 5    | `timeout 300`                                                | 当客户端闲置多长秒后关闭连接，如果指定为 0 ，表示关闭该功能  |
| 6    | `loglevel notice`                                            | 指定日志记录级别，Redis 总共支持四个级别：debug、verbose、notice、warning，默认为 notice |
| 7    | `logfile stdout`                                             | 日志记录方式，默认为标准输出，如果配置 Redis 为守护进程方式运行，而这里又配置为日志记录方式为标准输出，则日志将会发送给 /dev/null |
| 8    | `databases 16`                                               | 设置数据库的数量，默认数据库为0，可以使用SELECT 命令在连接上指定数据库id |
| 9    | `save <seconds> <changes>`Redis 默认配置文件中提供了三个条件：**save 900 1****save 300 10****save 60 10000**分别表示 900 秒（15 分钟）内有 1 个更改，300 秒（5 分钟）内有 10 个更改以及 60 秒内有 10000 个更改。 | 指定在多长时间内，有多少次更新操作，就将数据同步到数据文件，可以多个条件配合 |
| 10   | `rdbcompression yes`                                         | 指定存储至本地数据库时是否压缩数据，默认为 yes，Redis 采用 LZF 压缩，如果为了节省 CPU 时间，可以关闭该选项，但会导致数据库文件变的巨大 |
| 11   | `dbfilename dump.rdb`                                        | 指定本地数据库文件名，默认值为 dump.rdb                      |
| 12   | `dir ./`                                                     | 指定本地数据库存放目录                                       |
| 13   | `slaveof <masterip> <masterport>`                            | 设置当本机为 slave 服务时，设置 master 服务的 IP 地址及端口，在 Redis 启动时，它会自动从 master 进行数据同步 |
| 14   | `masterauth <master-password>`                               | 当 master 服务设置了密码保护时，slav 服务连接 master 的密码  |
| 15   | `requirepass foobared`                                       | 设置 Redis 连接密码，如果配置了连接密码，客户端在连接 Redis 时需要通过 AUTH <password> 命令提供密码，默认关闭 |
| 16   | ` maxclients 128`                                            | 设置同一时间最大客户端连接数，默认无限制，Redis 可以同时打开的客户端连接数为 Redis 进程可以打开的最大文件描述符数，如果设置 maxclients 0，表示不作限制。当客户端连接数到达限制时，Redis 会关闭新的连接并向客户端返回 max number of clients reached 错误信息 |
| 17   | `maxmemory <bytes>`                                          | 指定 Redis 最大内存限制，Redis 在启动时会把数据加载到内存中，达到最大内存后，Redis 会先尝试清除已到期或即将到期的 Key，当此方法处理 后，仍然到达最大内存设置，将无法再进行写入操作，但仍然可以进行读取操作。Redis 新的 vm 机制，会把 Key 存放内存，Value 会存放在 swap 区 |
| 18   | `appendonly no`                                              | 指定是否在每次更新操作后进行日志记录，Redis 在默认情况下是异步的把数据写入磁盘，如果不开启，可能会在断电时导致一段时间内的数据丢失。因为 redis 本身同步数据文件是按上面 save 条件来同步的，所以有的数据会在一段时间内只存在于内存中。默认为 no |
| 19   | `appendfilename appendonly.aof`                              | 指定更新日志文件名，默认为 appendonly.aof                    |
| 20   | `appendfsync everysec`                                       | 指定更新日志条件，共有 3 个可选值：**no**：表示等操作系统进行数据缓存同步到磁盘（快）**always**：表示每次更新操作后手动调用 fsync() 将数据写到磁盘（慢，安全）**everysec**：表示每秒同步一次（折中，默认值） |
| 21   | `vm-enabled no`                                              | 指定是否启用虚拟内存机制，默认值为 no，简单的介绍一下，VM 机制将数据分页存放，由 Redis 将访问量较少的页即冷数据 swap 到磁盘上，访问多的页面由磁盘自动换出到内存中（在后面的文章我会仔细分析 Redis 的 VM 机制） |
| 22   | `vm-swap-file /tmp/redis.swap`                               | 虚拟内存文件路径，默认值为 /tmp/redis.swap，不可多个 Redis 实例共享 |
| 23   | `vm-max-memory 0`                                            | 将所有大于 vm-max-memory 的数据存入虚拟内存，无论 vm-max-memory 设置多小，所有索引数据都是内存存储的(Redis 的索引数据 就是 keys)，也就是说，当 vm-max-memory 设置为 0 的时候，其实是所有 value 都存在于磁盘。默认值为 0 |
| 24   | `vm-page-size 32`                                            | Redis swap 文件分成了很多的 page，一个对象可以保存在多个 page 上面，但一个 page 上不能被多个对象共享，vm-page-size 是要根据存储的 数据大小来设定的，作者建议如果存储很多小对象，page 大小最好设置为 32 或者 64bytes；如果存储很大大对象，则可以使用更大的 page，如果不确定，就使用默认值 |
| 25   | `vm-pages 134217728`                                         | 设置 swap 文件中的 page 数量，由于页表（一种表示页面空闲或使用的 bitmap）是在放在内存中的，，在磁盘上每 8 个 pages 将消耗 1byte 的内存。 |
| 26   | `vm-max-threads 4`                                           | 设置访问swap文件的线程数,最好不要超过机器的核数,如果设置为0,那么所有对swap文件的操作都是串行的，可能会造成比较长时间的延迟。默认值为4 |
| 27   | `glueoutputbuf yes`                                          | 设置在向客户端应答时，是否把较小的包合并为一个包发送，默认为开启 |
| 28   | `hash-max-zipmap-entries 64 hash-max-zipmap-value 512`       | 指定在超过一定的数量或者最大的元素超过某一临界值时，采用一种特殊的哈希算法 |
| 29   | `activerehashing yes`                                        | 指定是否激活重置哈希，默认为开启（后面在介绍 Redis 的哈希算法时具体介绍） |
| 30   | `include /path/to/local.conf`                                | 指定包含其它的配置文件，可以在同一主机上多个Redis实例之间使用同一份配置文件，而同时各个实例又拥有自己的特定配置文件 |

## Redis连接

| 序号 | 命令及描述                                                   |
| :--- | :----------------------------------------------------------- |
| 1    | [AUTH password](https://www.runoob.com/redis/connection-auth.html) 验证密码是否正确 |
| 2    | [ECHO message](https://www.runoob.com/redis/connection-echo.html) 打印字符串 |
| 3    | [PING](https://www.runoob.com/redis/connection-ping.html) 查看服务是否运行 |
| 4    | [QUIT](https://www.runoob.com/redis/connection-quit.html) 关闭当前连接 |
| 5    | [SELECT index](https://www.runoob.com/redis/connection-select.html) 切换到指定的数据库 |

## Redis Stream

Redis Stream 是 Redis 5.0 版本新增加的数据结构，主要用于消息队列（MQ，Message Queue）。

### 原理

Redis Stream 提供了消息的持久化和主备复制功能，可以让任何客户端访问任何时刻的数据，并且能记住每一个客户端的访问位置，还能保证消息不丢失。

Redis Stream 的结构如下所示，它有一个消息链表，将所有加入的消息都串起来，每个消息都有一个唯一的 ID 和对应的内容。

![img](https://www.runoob.com/wp-content/uploads/2020/09/en-us_image_0167982791.png)

每个 Stream 都有唯一的名称，它就是 Redis 的 key，在我们首次使用 xadd 指令追加消息时自动创建。

上图解析：

- **Consumer Group** ：消费组，使用 XGROUP CREATE 命令创建，一个消费组有多个消费者(Consumer)。
- **last_delivered_id** ：游标，每个消费组会有个游标 last_delivered_id，任意一个消费者读取了消息都会使游标 last_delivered_id 往前移动。
- **pending_ids** ：消费者(Consumer)的状态变量，作用是维护消费者的未确认的 id。 pending_ids 记录了当前已经被客户端读取的消息，但是还没有 ack (Acknowledge character：确认字符）。

### 相关命令

**消息队列相关命令：**

- **XADD** - 添加消息到末尾
- **XTRIM** - 对流进行修剪，限制长度
- **XDEL** - 删除消息
- **XLEN** - 获取流包含的元素数量，即消息长度
- **XRANGE** - 获取消息列表，会自动过滤已经删除的消息
- **XREVRANGE** - 反向获取消息列表，ID 从大到小
- **XREAD** - 以阻塞或非阻塞方式获取消息列表

**消费者组相关命令：**

- **XGROUP CREATE** - 创建消费者组
- **XREADGROUP GROUP** - 读取消费者组中的消息
- **XACK** - 将消息标记为"已处理"
- **XGROUP SETID** - 为消费者组设置新的最后递送消息ID
- **XGROUP DELCONSUMER** - 删除消费者
- **XGROUP DESTROY** - 删除消费者组
- **XPENDING** - 显示待处理消息的相关信息
- **XCLAIM** - 转移消息的归属权
- **XINFO** - 查看流和消费者组的相关信息；
- **XINFO GROUPS** - 打印消费者组的信息；
- **XINFO STREAM** - 打印流信息
