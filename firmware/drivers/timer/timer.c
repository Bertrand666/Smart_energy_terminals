#include "timer.h"

TIM_HandleTypeDef htim3;

void MY_TIM3_Init(void)
{
  htim3.Instance = TIM3;
  htim3.Init.Prescaler = 8399;            /* 84MHz / 8400 = 10kHz */
  htim3.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim3.Init.Period = 9999;               /* 10000 * 0.1ms = 1s */
  htim3.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim3.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_ENABLE;
  HAL_TIM_Base_Init(&htim3);
  HAL_TIM_Base_Start_IT(&htim3);
}

void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
  if (htim->Instance == TIM3) {
    HAL_GPIO_TogglePin(GPIOF, GPIO_PIN_9);
  }
}
