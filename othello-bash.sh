#!/bin/bash

# Globals
declare -i board=(
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0
)

function main() {

    # Initialize board with default XOXO pattern in the centre
    board[28]=1
    board[29]=2
    board[36]=2
    board[37]=1

    # Main loop
    game_state="player_1_turn"  
    while [ $game_state != "game_over" ]; do
        
        # Show the current state of the board
        board_show

        # Player 1 (human) turn
        if [ $game_state = "player_1_turn" ]; then
            printf "Player 1 turn. Choose a row and column for your next move.\n"
            printf "Row: "
            read player1_row
            printf "Col: "
            read player1_col
            printf "Input: row=$player1_row, col=$player1_col\n"
            board_set player1_row player1_col 1
            game_state="player_2_turn"

        # Player 2 (computer) turn
        elif [ $game_state = "player_2_turn" ]; then
            printf "Player 2 turn. Computer does some magic...\n"
            get_test=$(board_get 4 5)
            printf "Value at position 4,5: $get_test"
            game_state="player_1_turn"
        
        fi
    done
}

# [board_show]
function board_show {
    printf "\n"
    for i in `seq 1 64`; do
        printf "%d " ${board[$i]}
        if (( $i % 8 == 0 )); then
            printf "\n"
        fi
    done
    printf "\n"
}

# [board_get]
# @param $1: The row position of the board space to return (1 to 8)
# @param $2: The col position of the board space to return (1 to 8)
# @return: Returns 0, 1 or 2. Add error checks! 
function board_get {
    declare -i row_pos=$1
    declare -i col_pos=$2
    array_pos=$(( ((row_pos-1) * 8) + (col_pos) ))
    echo "[board_get] row_pos=$row_pos, col_pos=$col_pos, array_pos=$array_pos"

    # Return
    echo ${board[array_pos]}
}

# [board_set]
# @param $1: The row position of the board space to set (1 to 8)
# @param $2: The col position of the board space to set (1 to 8)
# @param $3: The value to set
# @return: Return 0 if successful, 1 if error. Add error checks!
function board_set {
    declare -i row_pos=$1
    declare -i col_pos=$2
    declare -i value=$3
    array_pos=$(( ((row_pos-1) * 8) + (col_pos) ))
    board[$array_pos]=$value
}

main