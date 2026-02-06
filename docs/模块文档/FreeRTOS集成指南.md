# FreeRTOS 集成指南

> 本文档记录 FreeRTOS 的集成方法、任务划分和配置要点。

---

## 状态

🚧 **待完善** - 本文档为占位文档，将在 FreeRTOS 集成时完善。

---

## 规划内容

### 任务划分（建议）

| 任务名 | 优先级 | 栈大小 | 职责 |
|--------|--------|--------|------|
| sensor_task | 高 | 512 | 传感器采集 + 滤波 |
| comm_task | 中 | 1024 | ESP8266/MQTT 通信 |
| modbus_task | 中 | 512 | Modbus RTU 从站 |
| storage_task | 低 | 512 | FatFs 数据存储 |
| ui_task | 低 | 2048 | LVGL 界面刷新 |

### 配置要点

- [ ] FreeRTOSConfig.h 关键参数
- [ ] 堆内存管理方案（heap_4 推荐）
- [ ] 中断优先级配置
- [ ] SysTick 与 HAL_Delay 共存方案

### 同步机制

- [ ] 队列使用规范
- [ ] 信号量/互斥锁使用场景
- [ ] 事件组应用

---

## 参考资料

- [FreeRTOS 官方文档](https://www.freertos.org/Documentation/RTOS_book.html)
- [STM32 FreeRTOS 移植指南](https://www.st.com/resource/en/user_manual/um1722.pdf)

---

## 更新记录

| 日期 | 变更内容 |
|------|----------|
| 2026-02-06 | 创建占位文档 |
