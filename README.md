# systemverilog-cache
Testbench for a simple cache 

## Introduction
Here I show case a test bench for a small cache. I created the test bench as a small project to learn system verilog.

## Simulation
To run the test bench use the following link: [edaplayground.com](https://edaplayground.com/x/JW6a).  

## Description of the Design
The cache is a simple FIFO cache, modelled as a bit vector with 128 bits. Thus, it can well happen that a key is stored multiple times in the cache.
The keys and the values are stored next to each other in the bit vector. 

## Description of the Testbench
The testbench is inspired by a course on [udemy](https://www.udemy.com/share/106eVE3@xE5wjQxbBO7x8sIwnunN-WlFY0D7Yqwg1In5FCLTRZ4NXmHUl19RkfBiRWAyQsj2Ag==/).

There, they split the test bench into four concurrently running modules: test vector generator, driver, monitor and score board.


## Source of the Design
Design is taken from: https://bitbucket.org/spandeygit/learn\_verilog
With minor modifications from me
There is also a youtube video on this: https://youtu.be/1-15\_tPmrkQ

