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
# @param $1: Process type. Can be "process", "thread" (default "process")
function main() {

    # Command line arguments
    process_type="process"
    if [ ! -z $1 ]; then
        process_type=$1
    fi

    # Main loop
    game_state="player1_turn"
    while [ $game_state != "game_over" ]; do

        # Show the current state of the board
        board_show

        # Player 1 (human) turn
        if [ $game_state = "player1_turn" ]; then
            printf "Player 1 turn. Choose a row and column for your next move.\n"
            printf "Row (1-8): "
            read player1_row
            printf "Col (1-8): "
            read player1_col

            # Try the move. If it's invalid, board_set_move will return non-zero,
            # in which case the player just tries again.
            board_play_move $player1_row $player1_col 1
            if [ "$?" -ne "0" ]; then
                printf "\n*** Invalid move! Try again. ***\n\n"
            else
                game_state="player2_turn"
            fi

        # Player 2 (computer) turn
        elif [ $game_state = "player2_turn" ]; then
            printf "Player 2 turn. Computer does some magic...\n"
            game_state="player1_turn"
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

# [board_get_val]
# @param $1: Row position of the board space value to get (1 to 8)
# @param $2: Vol position of the board space value to get (1 to 8)
# @return: "0", "1" or "2" if success, "error" if error. 
function board_get_pos {
    row_pos=$1
    col_pos=$2
    
    # Make sure the location request is a valid position on the board
    # Think about moving the error check outside of here?
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
# @param $1: Row position of the board space to set (1 to 8)
# @param $2: Col position of the board space to set (1 to 8)
# @param $3: Value to set
# @return: 0 if success, 1 if error.
function board_set_pos {
    row_pos=$1
    col_pos=$2
    value=$3

    array_pos=$(( ((row_pos-1) * 8) + (col_pos - 1) ))
    board[$array_pos]=$value

    # Return as value
    return $return_val
}

# [board_set_range]
# @param $1: Start row position of the board space to set (1 to 8)
# @param $2: Start col position of the board space to set (1 to 8)
# @param $3: End row position of the board space to set (1 to 8)
# @param $4: End col position of the board space to set (1 to 8)
# @param $5: Value to set.
# @return: Nothing. Assume sucess, assume at this point it's a valid range.
function board_set_range {
    start_row_pos=$1
    start_col_pos=$2
    end_row_pos=$3
    end_col_pos=$4
    value=$5
    
    # Iterate + set over the range
    iterate_row=$start_row_pos
    iterate_col=$start_col_pos
    while (( ( iterate_row != end_row_pos ) || ( iterate_col != end_col_pos ) )); do
        if (( iterate_row > end_row_pos )); then
            iterate_row=$(( iterate_row - 1 ))
           # printf "[board_set_range] decreasing iterate_row, iterate_row=$iterate_row\n"
        elif (( iterate_row < end_row_pos )); then
            iterate_row=$(( iterate_row + 1 ))
            #printf "[board_set_range] increasing iterate_row, iterate_row=$iterate_row\n"
        fi
        if (( iterate_col > end_col_pos )); then
            iterate_col=$(( iterate_col - 1 ))
        elif (( iterate_col < end_col_pos )); then
            iterate_col=$(( iterate_col + 1 ))
        fi
        board_set_pos $iterate_row $iterate_col $value
    done
}

# [board_play_move]
# @description: Plays a move. Verifies the requested position if a valid move
#   space. If it is, sets the position, then flips all opponent pieces that 
#   were surrounded by the new move.
# @param $1: Row position of the new move (1 to 8)
# @param $2: Col position of the new move (1 to 8)
# @param $3: Value to set.
# @return: 0 if the move was played successfully, 1 if not.
function board_play_move {
    row_pos=$1
    col_pos=$2
    value=$3
    
    # Determine if the move is valid. There are a few things we need to look at.
    # First, make sure the requested position is valid and available. We can use
    # board_get_pos to verify this.
    if [ $(board_get_pos $row_pos $col_pos) -eq "0" ]; then
        # Next, make sure the requested position is a legal move. We can use
        # board_is_legal_move to verify this.
        board_is_legal_move $row_pos $col_pos $value
        is_legal=$?
        if [ "$is_legal" -eq "0" ]; then
            array_pos=$(( ((row_pos-1) * 8) + (col_pos - 1) ))
            # Everything is legal, set the new move!
            board[$array_pos]=$value
        else
            # Move was not legal, bail out here
            return 1
        fi
    else
        return 1
    fi

    # Now we need to flip opponent pieces that were just surrounded 
    # Iterate over adjacent positions to the new move
    for row in `seq $(( row_pos-1 )) $(( row_pos+1 ))`; do
        for col in `seq $(( col_pos-1 )) $(( col_pos+1 ))`; do

            # Don't even bother to check if this is a valid position on the 
            # board. If it's not, bash will return "0" which we don't care 
            # about.
            this_pos_value=$(board_get_pos $row $col)
            
            # Check if this position is adjacent to an opponent. If so, their
            # position values (1, 2) will add up to 3.
            if (( value + this_pos_value == 3 )); then

                # Now traverse the matrix in the direction of the opponent
                # piece. Continue until we either:
                # 1. Hit a 0 (empty), in which case the move is not valid.
                # 2. Hit the edge of the board, in which case the move is not valid
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
                        board_set_range $row_pos $col_pos $scan_row $scan_col $value
                    fi
                    scan_row=$(( scan_row + row_diff ))
                    scan_col=$(( scan_col + col_diff ))
                 done

            fi
        done
    done

    # Return as value
    return 0
}

# [board_is_legal_move]
# @param $1: Row position of the board space to verify (1 to 8)
# @param $2: Col position of the board space to verify (1 to 8)
# @param $3: Value to verify is legal.
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
            
            # Check if this position is adjacent to an opponent. If so, their
            # position values (1+2) will add up to 3.
            if (( value + this_pos_value == 3 )); then

                # Now traverse the matrix in the direction of the opponent
                # piece. Continue until we either:
                # 1. Hit a 0 (empty): move is not valid.
                # 2. Hit the edge of the board: move is not valid
                # 3. Hit one of our own pieces: move is valid

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