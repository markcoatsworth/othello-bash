#!/bin/bash

# Globals
board=(
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
# @param $1: Process type. Can either be "process", "thread" or empty (defaults to "process")
function main() {

    # Command line arguments
    process_type="process"
    if [ ! -z $1 ]; then
        process_type=$1
    fi

    # Main loop
    game_state="player_1_turn"  
    while [ $game_state != "game_over" ]; do

        # Show the current state of the board
        board_show

        # Player 1 (human) turn
        if [ $game_state = "player_1_turn" ]; then
            printf "Player 1 turn. Choose a row and column for your next move.\n"
            printf "Row (1-8): "
            read player1_row
            printf "Col (1-8): "
            read player1_col
            
            # Try the move. If it's invalid, board_set will return non-zero,
            # in which case the player just tries again.
            board_set_pos player1_row player1_col 1
            if [ "$?" -ne "0" ]; then
                printf "\n*** Invalid move! Try again. ***\n\n"
            else
                game_state="player_2_turn"
            fi

        # Player 2 (computer) turn
        elif [ $game_state = "player_2_turn" ]; then
            printf "Player 2 turn. Computer does some magic...\n"
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
function board_get_pos {
    row_pos=$1
    col_pos=$2
    
    # Make sure the location requests is a valid position on the board
    # Think about moving the error check outside of here? We want this function
    # to be super fast. Could assume we trust the inputs.
    return_val="error"  # Assume error until proven otherwise
    if (( row_pos >= 1 && row_pos <= 8 && col_pos >= 1 && col_pos <= 8 )); then
        array_pos=$(( ((row_pos-1) * 8) + (col_pos - 1) ))
       # printf "[board_get_pos] element at pos=$row_pos,$col_pos is ${board[$array_pos]}\n"
        return_val=${board[$array_pos]}
    fi
    
    # Return as expression
    echo $return_val
}

# [board_set_pos]
# @param $1: The row position of the board space to set (1 to 8)
# @param $2: The col position of the board space to set (1 to 8)
# @param $3: The value to set
# @return: 0 if success, 1 if error.
function board_set_pos {
    row_pos=$1
    col_pos=$2
    value=$3
    return_val=1 # Assume error until proven otherwise
    
    # Determine if the move is valid. There are a few things we need to look at.
    # First, make sure the requested position is valid and available. We can use
    # board_get to verify this.
    if [ $(board_get_pos $row_pos $col_pos) -eq "0" ]; then
        # Next, make sure the requested position is a legal move. We can use
        # board_is_legal_move to verify this.
        board_is_legal_move $row_pos $col_pos $value
        is_legal=$?
        if [ "$is_legal" -eq "0" ]; then
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
    return_val=1 # Assume illegal until proven otherwise

    # Iterate over adjacent positions to the requested position
    is_adjacent_opponent=0
    for row in `seq $(( row_pos-1 )) $(( row_pos+1 ))`; do
        for col in `seq $(( col_pos-1 )) $(( col_pos+1 ))`; do

            # Don't even bother to check if this is a valid position on the 
            # board. If it's not, bash will return "0" which we don't care 
            # about.
            this_pos_value=$(board_get_pos $row $col)
            
            # Check if this position is adjacent to an opponent. If so their
            # values will add up to 3.
            if (( value + this_pos_value == 3 )); then

                # Now traverse the matrix in the direction of the opponent
                # piece. Continue until we either:
                # 1. Hit a 0, in which case the move is not valid.
                # 2. Hit the edge of the board, in which case not valid
                # 3. Hit one of our own pieces, in which case the move is valid

                row_diff=$(( row - row_pos ))
                col_diff=$(( col - col_pos ))
                scan_row=$(( row + row_diff ))
                scan_col=$(( col + col_diff ))

                # The bounds on this loop are broken, fix them
                while (( scan_row >= 1 && scan_row <= 8 && scan_col >= 1 && scan_col <= 8 )); do
                    scan_val=$(board_get_pos $scan_row $scan_col)
                    if [ "$scan_val" -eq "0" ]; then
                        break
                    elif [ "$scan_val" -eq "$value" ]; then
                        return_val=0
                        break
                    fi
                    scan_row=$(( scan_row + row_diff ))
                    scan_col=$(( scan_col + col_diff ))
                 done

            fi
        done
    done

    # Return as value
    return $return_val
}

main