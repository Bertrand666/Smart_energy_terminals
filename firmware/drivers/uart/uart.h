#ifndef __UART_H__
#define __UART_H__

#ifdef __cplusplus
extern "C" {
#endif

#include "main.h"
#include <stddef.h>
#include <stdint.h>

extern UART_HandleTypeDef huart1;

void MY_USART1_UART_Init(void);
int uart_write(const uint8_t *data, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* __UART_H__ */

