# Reverse 400&500 for L-CTF 2016

## Legal Statement

Copyright of this repo belongs to Silver and XDSEC.

Unless otherwise stated, you are requested to follow GPLv3 to use code in this repo.

The following related parts are NOT allowed to use this code, unless a statement is signed and published by the author:

* Humensec (http://www.humensec.com)
* Network Behaviour Research Center (NBRC) in Xidian University (http://nbrc.xidian.edu.cn)
* School of Cyber Engineering of Xidian University (http://ce.xidian.edu.cn)
* Leaders, researchers, students and any other people directly related to entities above

ANY POSSIBLE actions will be committed if this statement had been violated.

## Note

You may need download a virtual machine from the website of ERIKA RTOS if you want to compile Re 500 by yourself.

You need a CPU supporting AVX instruction set to run Re 400

The following texts are in Chinese, and you may ask the author of this repo for futher explaination if you don't understand them. Sorry for any inconvenience.

## Writeup

### Re 400

题目试图用`magic_file`作为块链数据挖矿，挖到前3400个block之后，用他们的哈希值生成IV和Key，解密Flag字符串。题目除了去除了符号表之外，没有任何反调试和反分析内容，基本就是考察算法逆向能力。题目的一个切入点就是，通过trace可以发现在一系列函数中耗了很长时间，由此可以发现SHA256的相关代码，再分析上下文的代码，也就差不多能看出挖矿的过程了。结合题目前期给出的UID（转换成十进制搜索，可以发现是第一个block的Nonce值），以及后期给出的Bitcoin提示，应该是能明白程序在干什么的。

相关代码已经上传到Github了，这里就不多介绍。

### Re 500

关于Re500，首先向大家道歉，由于时间关系，出题人手残把`SIU_PGPDO`和`SIU_PGPDI`的地址值写反了，比赛结束后有队伍报告了这个问题……

这道题是一个跑在嵌入式设备中的程序，目标芯片是Freescale的MPC5674F，使用了Erika RTOS。程序原理是，初始化外部的LCD1602，并将flag打印到屏幕上。在设计的时候，我埋下的几个坑点有：

* 有时候IDA导入时，默认开了VLE，你要自己在**导入成功之后**去Options里关掉VLE，然后Reanalyze一下（导入的时候关掉VLE是没作用的，不知道是我的使用方法不对还是他自己的bug，有知道的还望指点下）。这个在题目描述里实际也是有的（"`I Hate Change`"，VLE是变长指令集）；
![Disable VLE](./img/ppc_set_opt.jpg "How to disable VLE during analysis process")
* 无意把寄存器写反，坑了一波……这个真不是有意的……再次向表哥们低头；
* 有的队伍看到ELF就先去用qemu跑了，这个应该是跑不起来的……用TRACE32应该可以搞，不过未必比静态分析方便；
* 程序是跑在一个RTOS上的，所以如何把RTOS的代码和业务代码分开，对没有过相关开发或逆向经验的选手可能有点麻烦（不过也完全可以借助FLIRT）；
* MCU和外设（LCD1602）的连线采用并行方式，但是D0-D7不是顺序接入的，有三根线被人为调换了位置，意在模拟由于PCB布线或生产问题，导致两个设备之间没办法用连续的一段IO口通信；
* 没有直接向LCD1602送出字符，而是先把字模写到了`CGRAM`，然后再显示到屏幕上，另外字模的显示字符和对应字母是不一致的，而且先解出来IO口的乱序规则才可以使用字模……；
* 有三段代码都能和LCD1602通信，但是仔细分析之后可以发现，只有一段代码比较像正确的代码，因为只有那段循环每次都有机会和外设通信，其他的是忽悠你的，毕竟连优先级都没有第一段高；

同样把代码传到了Github上，大家可以自行查阅。

拿到题后先正确的载入到IDA中，然后最简单的方法是直接查看字符串，有一段以FAIL开头的字符串，找到引用函数，然后直接去读。这种方法根本不需要对RTOS和业务代码做区分，比较快。通过向外发送的控制字，以及将数组取出分析，可以知道这应该是在送字模，但是字模是乱掉的。解决办法就是，要么自己根据FLAG格式推测，要么从送控制字之前的几个移位操作分析出硬件连线。

解题脚本如下：

```python
#!/usr/bin/python

srctext="FAIL{tX1NJfGxnatFxY63Wxmlpxh12Z0h5xeGxaH56Nfy}" #get from bin

charmap={ # get charmap from bin
0xA9:[0x46, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x46], 
0xAA:[0x00, 0x00, 0x00, 0x15, 0x15, 0x46, 0x42, 0x42], 
0xAB:[0x00, 0x00, 0x00, 0x44, 0x03, 0x45, 0x03, 0x45], 
0xAC:[0x00, 0x00, 0x00, 0x47, 0x02, 0x44, 0x01, 0x47], 
0xAD:[0x00, 0x00, 0x00, 0x45, 0x03, 0x02, 0x02, 0x45], 
0xAE:[0x04, 0x06, 0x04, 0x04, 0x04, 0x04, 0x04, 0x46], 
0xAF:[0x53, 0x53, 0x53, 0x53, 0x15, 0x15, 0x15, 0x15], 
0xA0:[0x12, 0x02, 0x02, 0x46, 0x03, 0x03, 0x03, 0x46], 
0xA1:[0x16, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x57], 
0xA8:[0x46, 0x11, 0x11, 0x40, 0x04, 0x02, 0x10, 0x57], 
0xF9:[0x00, 0x00, 0x00, 0x44, 0x03, 0x47, 0x02, 0x45], 
0xFA:[0x00, 0x00, 0x00, 0x56, 0x15, 0x15, 0x15, 0x15], 
0xFB:[0x46, 0x11, 0x11, 0x46, 0x11, 0x11, 0x11, 0x46], 
0xFC:[0x13, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x44], 
0xFD:[0x04, 0x00, 0x00, 0x06, 0x04, 0x04, 0x04, 0x46], 
0xFE:[0x46, 0x11, 0x01, 0x44, 0x01, 0x01, 0x11, 0x46], 
0xFF:[0x00, 0x00, 0x00, 0x53, 0x06, 0x02, 0x02, 0x16], 
0xF0:[0x56, 0x03, 0x03, 0x46, 0x02, 0x02, 0x02, 0x16], 
0xF1:[0x47, 0x11, 0x10, 0x06, 0x40, 0x01, 0x11, 0x56], 
0xF2:[0x46, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x46], 
0xF3:[0x47, 0x40, 0x40, 0x40, 0x40, 0x40, 0x50, 0x16], 
0xF4:[0x00, 0x00, 0x00, 0x53, 0x03, 0x03, 0x03, 0x45], 
0xF5:[0x56, 0x03, 0x03, 0x46, 0x03, 0x03, 0x03, 0x56], 
0xF6:[0x56, 0x03, 0x03, 0x46, 0x42, 0x03, 0x03, 0x17], 
0xF7:[0x17, 0x03, 0x42, 0x06, 0x42, 0x42, 0x03, 0x17], 
0xE8:[0x57, 0x50, 0x40, 0x04, 0x04, 0x04, 0x04, 0x04], 
0xE9:[0x40, 0x00, 0x44, 0x40, 0x40, 0x40, 0x40, 0x16], 
0xEA:[0x53, 0x03, 0x07, 0x07, 0x43, 0x43, 0x03, 0x17], 
0xEB:[0x40, 0x44, 0x42, 0x42, 0x50, 0x47, 0x40, 0x41], 
0xEC:[0x04, 0x04, 0x44, 0x42, 0x42, 0x47, 0x03, 0x13], 
0xED:[0x00, 0x56, 0x03, 0x03, 0x03, 0x46, 0x02, 0x16], 
0xEE:[0x00, 0x00, 0x00, 0x47, 0x40, 0x04, 0x04, 0x47], 
0xEF:[0x45, 0x03, 0x10, 0x10, 0x51, 0x11, 0x03, 0x44], 
0xE0:[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x57], 
0xE1:[0x56, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x56], 
0xE2:[0x57, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x57], 
0xD9:[0x47, 0x11, 0x10, 0x10, 0x10, 0x10, 0x11, 0x46], 
0xDA:[0x12, 0x02, 0x02, 0x43, 0x42, 0x46, 0x03, 0x17], 
0xDB:[0x00, 0x00, 0x00, 0x44, 0x03, 0x03, 0x03, 0x44], 
0xDC:[0x13, 0x03, 0x03, 0x47, 0x03, 0x03, 0x03, 0x13], 
0xDD:[0x13, 0x03, 0x03, 0x42, 0x42, 0x44, 0x04, 0x04], 
0xDE:[0x16, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x57], 
0xDF:[0x57, 0x10, 0x10, 0x56, 0x01, 0x01, 0x11, 0x46], 
0xD0:[0x00, 0x00, 0x00, 0x53, 0x42, 0x04, 0x42, 0x53], 
0xD1:[0x57, 0x15, 0x04, 0x04, 0x04, 0x04, 0x04, 0x46], 
0xD2:[0x12, 0x02, 0x02, 0x46, 0x03, 0x03, 0x03, 0x17], 
0xD3:[0x53, 0x42, 0x42, 0x04, 0x04, 0x04, 0x04, 0x46], 
0xD4:[0x57, 0x03, 0x42, 0x46, 0x42, 0x02, 0x02, 0x16], 
0xD5:[0x46, 0x11, 0x11, 0x11, 0x47, 0x01, 0x03, 0x46], 
0xD6:[0x00, 0x04, 0x04, 0x46, 0x04, 0x04, 0x04, 0x41], 
0xD7:[0x46, 0x50, 0x10, 0x56, 0x11, 0x11, 0x11, 0x46], 
0xC8:[0x00, 0x45, 0x03, 0x03, 0x03, 0x45, 0x01, 0x41], 
0xC9:[0x00, 0x17, 0x03, 0x42, 0x44, 0x04, 0x04, 0x12], 
0xCA:[0x46, 0x11, 0x11, 0x11, 0x17, 0x51, 0x46, 0x41], 
0xCB:[0x00, 0x00, 0x00, 0x17, 0x03, 0x42, 0x44, 0x04], 
0xCC:[0x53, 0x42, 0x42, 0x04, 0x04, 0x42, 0x42, 0x53], 
0xCD:[0x57, 0x50, 0x40, 0x04, 0x04, 0x02, 0x03, 0x57], 
0xCE:[0x15, 0x15, 0x15, 0x46, 0x42, 0x42, 0x42, 0x42], 
0xCF:[0x00, 0x45, 0x03, 0x44, 0x02, 0x47, 0x02, 0x45], 
0xC0:[0x00, 0x00, 0x00, 0x56, 0x03, 0x03, 0x03, 0x17], 
0xC1:[0x41, 0x04, 0x04, 0x47, 0x04, 0x04, 0x04, 0x47], 
0xC2:[0x57, 0x03, 0x42, 0x46, 0x42, 0x02, 0x03, 0x57], 
0xC7:[0x41, 0x01, 0x01, 0x45, 0x03, 0x03, 0x03, 0x45], 
0xE3:[0x41, 0x40, 0x40, 0x04, 0x40, 0x40, 0x40, 0x41], 
0xE5:[0x06, 0x04, 0x04, 0x40, 0x04, 0x04, 0x04, 0x06]
}
for i in srctext:
    c = list(charmap[0x98^ord(i)])
    c = [0]*(8-len(c))+c
    for r in c:
        if type(r)==str:
            r = ord(r)
        # swap the io line
        r=((r&0b00000001))        |((r&0b00000010)<<2)        |((r&0b00000100))        |((r&0b00001000)>>3)        |((r&0b00010000))        |((r&0b00100000))        |((r&0b01000000)>>5)        |((r&0b10000000))
        # convert to graph
        r = bin(r)[2:]
        r = '0'*(8-len(r))+r
        r = r.replace('0',' ')
        r = r.replace('1','\x18')
        print(r)
    input()

```
