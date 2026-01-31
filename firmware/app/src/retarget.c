  #include "uart.h"

  #include <errno.h>
  #include <stdio.h>
  #include <sys/unistd.h>

  void retarget_stdio_init(void)  // 关闭缓冲，即使没换行也直接输出
  {
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
  }

  int _write(int file, char *ptr, int len)
  {
    if (ptr == NULL || len <= 0)
    {
      return 0;
    }

    if (file == STDOUT_FILENO || file == STDERR_FILENO)
    {
      int written = 0;
      for (int i = 0; i < len; i++)
      {
        if (ptr[i] == '\n')
        {
          if (uart_write((const uint8_t *)"\r", 1) < 0)
          {
            return -1;
          }
          written++;
        }

        if (uart_write((const uint8_t *)&ptr[i], 1) < 0)
        {
          return -1;
        }
        written++;
      }
      return written;
    }

    errno = EBADF;
    return -1;
  }
