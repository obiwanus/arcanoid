# Arcanoid

Project goals:
- Write an arkanoid game in x86 assembly
- Make at least 5 levels
- Support different kinds of bricks
- Support buffs and debuffs
- Actually finish the game

## Video preview of the resulting game
Yay programmer art!
[![Arcanoid preview](https://img.youtube.com/vi/gWymbmSJbuE/0.jpg)](https://www.youtube.com/watch?v=gWymbmSJbuE)

## Prerequisites
- Install clang
- Install libc6-dev-i386
- Install libx11-dev:i386 libx11-dev
- Install nasm

## Compilation
`asm/` contains the asm source
- `cd asm`
- `make`
- `./arcanoid` to run the game

`c/` contains the C source
- `cd c/`
- `make`
- `./arcanoid` to run the game

Both are the versions of the same game. I first wrote the C version and then roughly translated it into 32-bit assembly.
