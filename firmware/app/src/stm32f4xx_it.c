/**
  ******************************************************************************
  * @file    Templates/Src/stm32f4xx_it.c
  * @author  MCD Application Team
  * @brief   Main Interrupt Service Routines.
  ******************************************************************************
  */

/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "stm32f4xx_it.h"
#include <stdio.h>

/* Private functions ---------------------------------------------------------*/

/******************************************************************************/
/*            Cortex-M4 Processor Exceptions Handlers                         */
/******************************************************************************/

/*
 * 注意：NMI_Handler, SVC_Handler, DebugMon_Handler, PendSV_Handler
 * 已在启动文件中弱定义(Weak)，此处删除空实现以减少代码量。
 */

/**
  * @brief  This function handles Hard Fault exception.
  * @param  None
  * @retval None
  */
void HardFault_Handler(void)
{
#ifdef DEBUG
  printf("\n\r[Fault] HardFault! HFSR:0x%08lX, CFSR:0x%08lX\n\r", SCB->HFSR, SCB->CFSR);
  // 简单的软件延时，等待串口数据发送完毕
  for(volatile int i = 0; i < 1000000; i++);
#endif
  NVIC_SystemReset();
}

/**
  * @brief  This function handles Memory Manage exception.
  * @param  None
  * @retval None
  */
void MemManage_Handler(void)
{
#ifdef DEBUG
  printf("\n\r[Fault] MemManage! CFSR:0x%08lX, MMFAR:0x%08lX\n\r", SCB->CFSR, SCB->MMFAR);
  for(volatile int i = 0; i < 1000000; i++);
#endif
  NVIC_SystemReset();
}

/**
  * @brief  This function handles Bus Fault exception.
  * @param  None
  * @retval None
  */
void BusFault_Handler(void)
{
#ifdef DEBUG
  printf("\n\r[Fault] BusFault! CFSR:0x%08lX, BFAR:0x%08lX\n\r", SCB->CFSR, SCB->BFAR);
  for(volatile int i = 0; i < 1000000; i++);
#endif
  NVIC_SystemReset();
}

/**
  * @brief  This function handles Usage Fault exception.
  * @param  None
  * @retval None
  */
void UsageFault_Handler(void)
{
#ifdef DEBUG
  printf("\n\r[Fault] UsageFault! CFSR:0x%08lX\n\r", SCB->CFSR);
  for(volatile int i = 0; i < 1000000; i++);
#endif
  NVIC_SystemReset();
}

/**
  * @brief  This function handles SysTick Handler.
  * @param  None
  * @retval None
  */
void SysTick_Handler(void)
{
  HAL_IncTick();
}

/******************************************************************************/
/*                 STM32F4xx Peripherals Interrupt Handlers                   */
/******************************************************************************/

extern TIM_HandleTypeDef htim3;

void TIM3_IRQHandler(void)
{
  HAL_TIM_IRQHandler(&htim3);
}
