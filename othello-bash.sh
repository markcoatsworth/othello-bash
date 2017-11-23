#!/bin/bash

# Globals
declare -i board=(
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 1 2 0 0 0 
    0 0 0 2 1 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0
)

# [main]
function main() {

    # Show the current state of the board
    board_show

    # Main loop
    game_state="player_1_turn"  
    while [ $game_state != "game_over" ]; do

        # Player 1 (human) turn
        if [ $game_state = "player_1_turn" ]; then
            printf "Player 1 turn. Choose a row and column for your next move.\n"
            printf "Row (1-8): "
            read player1_row
            printf "Col (1-8): "
            read player1_col
            
            # Try the move. If it's invalid, board_set will return non-zero,
            # in which case the player just tries again.
            board_set player1_row player1_col 1
            if [ $? != 0 ]; then
                printf "\n*** Invalid move! Try again. ***\n\n"
            else
                board_show
                game_state="player_2_turn"
            fi

        # Player 2 (computer) turn
        elif [ $game_state = "player_2_turn" ]; then
            printf "Player 2 turn. Computer does some magic...\n"
            board_show
            game_state="player_1_turn"
        fi
    done
}

# [board_show]
# @return: Nothing. Just output the board to stdout.
function board_show {
    printf "\n"
    for i in `seq 0 63`; do
        printf "%d " ${board[$i]}
        if (( ($i + 1) % 8 == 0 )); then
            printf "\n"
        fi
    done
    printf "\n"
}

# [board_get]
# @param $1: The row position of the board space to return (1 to 8)
# @param $2: The col position of the board space to return (1 to 8)
# @return: "0", "1" or "2" if success, "error" if error. 
function board_get {
    row_pos=$1
    col_pos=$2
    
    # Make sure the location requests is a valid position on the board
    return_val="error"  # Assume error until proven otherwise
    if (( row_pos >= 1 && row_pos <= 8 && col_pos >= 1 && col_pos <= 8 )); then
        array_pos=$(( ((row_pos-1) * 8) + (col_pos - 1) ))
        return_val=${board[$array_pos]}
    fi
    
    # Return as expression
    echo $return_val
}

# [board_set]
# @param $1: The row position of the board space to set (1 to 8)
# @param $2: The col position of the board space to set (1 to 8)
# @param $3: The value to set
# @return: 0 if success, 1 if error.
function board_set {
    row_pos=$1
    col_pos=$2
    value=$3
    return_val=1 # Assume error until proven otherwise
    
    # Determine if the move is valid. There are a few things we need to look at.
    # First, make sure the requested position is valid and available. We can use
    # board_get to verify this.
    if [ $(board_get $row_pos $col_pos) -eq "0" ]; then
        # Next, make sure the requested position is a legal move. We can use
        # board_is_legal_move to verify this.
        board_is_legal_move $row_pos $col_pos $value
        if [ $? = 0 ]; then
            array_pos=$(( ((row_pos-1) * 8) + (col_pos - 1) ))
            board[$array_pos]=$value
            return_val=0
        fi
    fi

    # Return as value
    return $return_val
}

# [board_is_legal_move]
# @param $1: The row position of the board space to verify (1 to 8)
# @param $2: The col position of the board space to verify (1 to 8)
# @param $3: The value to verify is legal.
# @return: 0 if the move is legal, 1 if not.
function board_is_legal_move {
    row_pos=$1
    col_pos=$2
    value=$3
    return_val=0

    # Return as value
    return $return_val
}

main