# Build kernel

## clone kernel code of specific version

## make menuconfig

## make

## debug

使用buildroot构建内核。在container内部启动qemu, 并尝试在host端使用gdb对内核进行调试。  

Q: 这里有一个关键问题, container通过namespace机制和外界隔离，拥有独立的网络视图，那么此时host-gdb该如何访问container qemu所监听的网络接口呢？  
A: 参见[port_publishing](https://docs.docker.com/engine/network/port-publishing/),docker允许“publish a container's port(s) to the host".为了实现这个功能，需要在docker run时通过-p指定需要publish的端口。  
其语法格式如下：  
docker run -p [host_ip] : host_port : container_post.  
这里的port是针对tcp连接而言的，官方还提供了publish UDP端口的方法，在此不赘述。  

Q: 为什么这里是"publish a container's port", 而不是"publish a constainer's ip:port"?  
A:  

Q: 在"publish a container's port"之后，container's qemu为什么监听的是"0.0.0.0:1234",即允许来自所有ip地址的port 1234的连接？  
A: 
## ref
read this (command at 7/24/2026) :  https://iximiuz.com/en/posts/docker-publish-container-ports/
https://github.com/bitristan/docker-linux-2.6.26-build
