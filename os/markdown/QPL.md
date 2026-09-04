# QPL

[QPL (Intel Query Processing Library)](https://github.com/intel/qpl/) 是一个开源库，为 Intel CPU 提供高性能查询处理操作。

QPL 的定位是把压缩、解压缩和基础 analytics primitive 抽象成统一 API：在支持 IAA 的平台上可以走硬件加速路径，在其他平台或不适合硬件执行的场景下回退到高度优化的软件实现。

| 执行路径 | 说明 | 适用场景 |
| --- | --- | --- |
| Hardware path | 通过 IAA 执行 job | Sapphire Rapids 等支持 IAA 的平台 |
| Software path | 在 CPU core 上执行 | 不支持 IAA 或需要纯软件可移植性 |
| Auto path | 优先尝试 IAA，失败时回退 CPU | 兼顾性能与兼容性 |

详见 [IAA.md](./IAA.md)。
