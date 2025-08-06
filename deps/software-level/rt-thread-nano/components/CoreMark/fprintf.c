#include <stdarg.h>
#include <rtthread.h>
#include <string.h>

// 复用xprintf.c里的浮点转字符串逻辑
static void float_to_str(double fv, int prec, char *buf, int bufsize)
{
    int i = 0, j;
    long ipart;
    double fpart;
    char s[16];

    if (fv < 0) {
        buf[i++] = '-';
        fv = -fv;
    }
    ipart = (long)fv;
    fpart = fv - ipart;

    // 整数部分
    j = 0;
    long v = ipart;
    do {
        s[j++] = (char)(v % 10) + '0';
        v /= 10;
    } while (v && j < (int)sizeof(s));
    while (j > 0 && i < bufsize - 1) buf[i++] = s[--j];

    // 小数点
    if (prec > 0 && i < bufsize - 1) buf[i++] = '.';

    // 小数部分
    for (j = 0; j < prec && i < bufsize - 1; j++) {
        fpart *= 10;
        int digit = (int)fpart;
        buf[i++] = '0' + digit;
        fpart -= digit;
    }
    buf[i] = '\0';
}

// 支持浮点的kprintf
void rt_fkprintf(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);

    const char *p = fmt;
    char ch;
    while ((ch = *p)) {
        if (ch == '%') {
            const char *start = p;
            p++;
            int width = 0, prec = 6, left = 0, zero = 0;
            // 解析标志
            if (*p == '0') { zero = 1; p++; }
            if (*p == '-') { left = 1; p++; }
            // 解析宽度
            while (*p >= '0' && *p <= '9') {
                width = width * 10 + (*p - '0');
                p++;
            }
            // 解析精度
            if (*p == '.') {
                p++;
                prec = 0;
                while (*p >= '0' && *p <= '9') {
                    prec = prec * 10 + (*p - '0');
                    p++;
                }
            }
            // 解析长度
            if (*p == 'l' || *p == 'L') p++;
            // 类型
            if (*p == 'f' || *p == 'F') {
                double fv = va_arg(args, double);
                char buf[32];
                float_to_str(fv, prec, buf, sizeof(buf));
                rt_kprintf("%s", buf);
                p++;
                continue;
            }
            // 其他类型直接传递给rt_kprintf
            int len = p - start + 1;
            char fmtbuf[16];
            strncpy(fmtbuf, start, len);
            fmtbuf[len] = '\0';
            if (*p) {
                if (*p == 'd' || *p == 'u' || *p == 'x' || *p == 'X' ||
                    *p == 's' || *p == 'c' || *p == 'p' || *p == 'o') {
                    // 只处理常见类型
                    if (*p == 's') {
                        char *str = va_arg(args, char *);
                        rt_kprintf(fmtbuf, str);
                    } else if (*p == 'c') {
                        int c = va_arg(args, int);
                        rt_kprintf(fmtbuf, c);
                    } else {
                        int v = va_arg(args, int);
                        rt_kprintf(fmtbuf, v);
                    }
                    p++;
                    continue;
                }
            }
            // 未知类型直接输出%
            rt_kprintf("%%");
        } else {
            rt_kprintf("%c", ch);
            p++;
        }
    }

    va_end(args);
}
