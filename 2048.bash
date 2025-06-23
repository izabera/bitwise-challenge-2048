#!/bin/bash

# 2048 game with 64 bits of state

# there are 12 possible values for each cell
# 2^64 / 12^16 ~ 99.7
# so we can have up to 99 different random seeds

cereal () {
    STATE=0
    for i in {15..0}; do
        ((STATE=STATE*12+board[i]))
    done
    ((STATE=STATE*99+(rng%99+99)%99))
}

decereal () {
    local i val=$1
    if ((val < 0)); then
        #      2^64%99=16                          99^-1 % 2^64
        ((rng=(val%99+16+99)%99, val-=rng, val*=12670490878911611211))
    else
        ((rng=val%99, val/=99))
    fi
    for i in {0..15}; do
        ((board[i]=(val%12+12)%12, val/=12))
    done
}
rand='rng=rng*17+19,(rng%99+99)%99'



trap "stty echo; printf '\e[?25h'" exit
stty -echo; printf '\e[?25l'



bg=(
    253 230 229 222
    215 208 202 223
    221 214 209 220
)
fg=(
    251 232 232 232
    255 255 255 232
    232 255 255 232
)
texts=(
    '      ' '   2  ' '   4  ' '   8  '
    '  16  ' '  32  ' '  64  ' '  128 '
    '  256 ' '  512 ' ' 1024 ' ' 2048 '
)

cell () {
    printf -v REPLY \
        '\e[2A\e[38;5;%s;48;5;%sm      \e[6D\e[B%s\e[6D\e[B      \e[m' \
        "${fg[$1]}" "${bg[$1]}" "${texts[$1]}"
}

draw () {
    printf '\e[10A\e[24D'
    for i in {0..3}; do
        for j in {0..3}; do
            cell "${board[i*4+j]}"
            printf %s "$REPLY"
        done
        ((i<3)) && printf '\e[3B\e[24D'
    done
    printf '\nSTATE=%u rng=%u\e[K\r' "$STATE" "$(((rng%99+99)%99))"
}

open () {
    local i list
    for i in {0..15}; do
        ((board[i])) || list+=("$i")
    done
    ((${#list[@]})) && board[list[rand%${#list[@]}]]=$((rand%2+1))
}

rot () {
    local tmp i j
    for i in {0..3}; do
        for j in {0..3}; do
            ((tmp[j*4+3-i]=board[i*4+j]))
        done
    done
    board=("${tmp[@]}")
}

squish () {
    local tmp i j

    for j in {0..3}; do
        # remove empty cells first
        tmp=()
        for i in {0..3}; do
            ((board[i*4+j])) && tmp+=("${board[i*4+j]}")
        done
        for i in {0..3}; do
            ((squished |= board[i*4+j] != tmp[i], board[i*4+j] = tmp[i]))
        done

        # now we can only have the following cases:
        # x x y y -> X Y 0 0    squish first and last
        # x x a b -> X a b 0    squish first
        # a x x b -> a X b 0    squish mid
        # a b x x -> a b X 0    squish last
        # a b c d -> a b c d    no squish!  >:|
        tmp=1
        if   (( board[j] && board[j+8] && board[j]==board[j+4] && board[j+8]==board[j+12] )); then
             ((
                board[j]++,
                board[j+4] = board[j+8] + 1,
                board[j+8] = board[j+12] = 0
             ))
        elif (( board[j] && board[j]==board[j+4])); then
             ((
                board[j]++,
                board[j+4] = board[j+8],
                board[j+8] = board[j+12],
                board[j+12] = 0
             ))
        elif (( board[j+4] && board[j+4]==board[j+8] )); then
             ((
                board[j+4]++,
                board[j+8] = board[j+12],
                board[j+12] = 0
             ))
        elif (( board[j+8] && board[j+8]==board[j+12] )); then
             ((
                board[j+8]++,
                board[j+12] = 0
             ))
        else
            tmp=0
        fi
        ((squished |= tmp ))
    done
}

move () {
    local squished
    case $1 in
        w) squish ;;
        a) rot; squish; rot; rot; rot ;;
        s) rot; rot; squish; rot; rot ;;
        d) rot; rot; rot; squish; rot ;;
    esac
    (( squished ))
}

checkend () {
    local i tmp
    for i in {0..15}; do
        ((board[i]==11)) && { printf '\nyou win! :)\n'; return; }
    done

    # if any move squishes anything we can continue
    local board=("${board[@]}")
    move w || move a || move s || move d && return 1
    printf '\nyou lose :(\n'
}



board=()
if [[ $STATE ]]; then
    decereal "$STATE"
else
    ((rng=(${rng-RANDOM}%99+99)%99))
    open
    open
fi



echo press wasd to move
for _ in {0..11}; do echo; done

while :; do
    cereal
    draw
    checkend && break
    read -rn1
    [[ $REPLY = [wasd] ]] && move "$REPLY" && open
done
