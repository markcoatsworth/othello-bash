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
player1_pieces=( 27 36 )
player2_pieces=( 28 35 )
player1_available_moves=( 20 29 34 43 )
player2_available_moves=( 19 26 37 44 )

# [main]
# @param $1: Process type. Can be "process", "thread" (default "process")
function main() {

    # Command line arguments. Only process the first one here to determine
    # if this is a process or a process thread.
    process_type="process"
    if [ ! -z $1 ]; then process_type=$1; fi

    # If this is a process thread, call the handler function, which will deal
    # with the rest of the command line arguments. Once that is complete, exit.
    if [ "$process_type" = "thread" ]; then
        thread $@
        exit
    fi

    # Main process loop
    game_state="player1_turn"
    level_num=2
    while [ $game_state != "game_over" ]; do

        # Show the current state of the board
        board_show

        # Show the state of the board
        printf "Player 1 pieces: ${player1_pieces[*]}\n"
        printf "Player 2 pieces: ${player2_pieces[*]}\n"
        printf "Player 1 available moves: ${player1_available_moves[*]}\n"
        printf "Player 2 available moves: ${player2_available_moves[*]}\n\n"

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
                # Move was successful. Evaluate player 2 available moves. If
                # they have none, the game is over. Otherwise, player 2 turn.
                set_available_moves 2
                if [ "${#player2_available_moves[@]}" = "0" ]; then
                    game_state="game_over"
                else
                    game_state="player2_turn"
                fi
            fi

        # Player 2 (computer) turn
        elif [ $game_state = "player2_turn" ]; then
            printf "Player 2 turn. Computer is thinking...\n"

            # Pick the best move determined by our evaluation function.
            evaluate_available_moves 2 $level_num
            player2_best_move=$?
            player2_move_row=$(( ( player2_best_move / 8 ) + 1 ))
            player2_move_col=$(( ( player2_best_move % 8 ) + 1 ))
            board_play_move $player2_move_row $player2_move_col 2
            printf "Player 2 played at row $player2_move_row, col $player2_move_col.\n"

            # Evaluate player 1 available moves. If they have none, the game 
            # is over. Otherwise, player 1 turn.
            set_available_moves 1
            if [ "${#player1_available_moves[@]}" = "0" ]; then
                game_state="game_over"
            else
                game_state="player1_turn"
            fi
        fi

    done

    # Game over! Figure out who won.
    printf "Game over!\n"
    player1_score=${#player1_pieces[@]}
    player2_score=${#player2_pieces[@]}
    printf "Player 1 has $player1_score pieces\n"
    printf "Player 2 has $player2_score pieces\n"
    if (( player1_score > player2_score )); then
        printf "Player 1 wins!\n"
    else
        printf "Player 2 wins!\n"
    fi
}

# [thread]
# @description: Main control loop for "thread" processes, which are not
#   technically threads but are being used in a similar way.

function thread {
    local player_num=$2
    local suggested_move=$3
    local results_filename=$4
    local level_num=$5
    local move_result

    printf "[thread_$$] player_num=$player_num, suggested_move=$suggested_move, level_num=$level_num\n"

    # Set the state of the game (board, player1_pieces, player2_pieces) based on
    # remaining command-line arguments
    player1_pieces=( )
    player2_pieces=( )
    shift 5
    for index in `seq 0 63`; do
        board[$index]=$1
        if [ "$1" = "1" ]; then player1_pieces+=($index); fi
        if [ "$1" = "2" ]; then player2_pieces+=($index); fi
        shift
    done

    # Play the suggested move
    move_row=$(( ( suggested_move / 8 ) + 1 ))
    move_col=$(( ( suggested_move % 8 ) + 1 ))
    board_play_move $move_row $move_col $player_num
    
    # At this point, if we are on level 0, then return the difference between
    # ${#player1_pieces[@]} and ${#player2_pieces[@]}.

    # If we are on level >= 1, then evaluate further moves down the decision
    # tree.

    # Determine the result of the move, which is the difference in number of
    # pieces between the player who just player ($player_num) and the opponent
    if (( level_num >= 1 )); then
        if [ "$player_num" = "1" ]; then
            evaluate_available_moves 2 $level_num
        elif [ "$player_num" = "2" ]; then
            evaluate_available_moves 1 $level_num
        fi
        move_result=$?
        printf "[thread_$$] for level=$level_num, move_result=$move_result\n"
    else
        # Although we use the player_num variable to track which player we're
        # currently evaluating moves for, we are ALWAYS trying to get the best 
        # score for player 2 (computer). So the final result will always 
        # represent the number of player 2 pieces more than player 1 pieces.
        move_result=$(( ${#player2_pieces[@]} - ${#player1_pieces[@]} ))
    fi
    #printf "[thread_$$] after move, player1_pieces=(${player1_pieces[*]}), player2_pieces=(${player2_pieces[*]}), move_diff=$move_diff\n"

    # Output results
    echo $suggested_move=$move_result >> $results_filename
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
    local row_pos=$1
    local col_pos=$2
    
    # Make sure the location request is a valid position on the board
    # Think about moving the error check outside of here?
    return_val="error"  # Assume error until proven otherwise
    if (( row_pos >= 1 && row_pos <= 8 && col_pos >= 1 && col_pos <= 8 )); then
        array_pos=$(( ((row_pos-1) * 8) + (col_pos-1) ))
        return_val=${board[$array_pos]}
    fi
    
    # Return as expression
    echo $return_val
}

# [board_set_pos]
# @description: Set a position on the board, and adjust the player_pieces arrays as needed.
# @param $1: Row position of the board space to set (1 to 8)
# @param $2: Col position of the board space to set (1 to 8)
# @param $3: Value to set
# @return: 0 if success, 1 if error.
function board_set_pos {
    local row_pos=$1
    local col_pos=$2
    local new_pos_value=$3

    array_pos=$(( ((row_pos-1) * 8) + (col_pos - 1) ))
    old_pos_value=${board[$array_pos]}
    board[$array_pos]=$value

    if (( new_pos_value == 1 )); then
        array_contains $array_pos "${player1_pieces[@]}"
        if [ "$?" = "1" ]; then
            #printf "[board_set_pos] adding $array_pos to player 1\n"
            player1_pieces+=($array_pos)
            #printf "[board_set_pos] removing $array_pos from player 2, old_pos_value=$old_pos_value\n"
            if [ "$old_pos_value" = "2" ]; then
                array_remove $array_pos "player2_pieces"
            fi
        fi
    elif (( new_pos_value == 2 )); then
        array_contains $array_pos "${player2_pieces[@]}"
        if [ "$?" = "1" ]; then
            #printf "[board_set_pos] adding $array_pos to player 2\n"
            player2_pieces+=($array_pos)
            #printf "[board_set_pos] removing $array_pos from player 1, old_pos_value=$old_pos_value\n"
            if [ "$old_pos_value" = "1" ]; then
                array_remove $array_pos "player1_pieces"
            fi
        fi
    fi

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
    local start_row_pos=$1
    local start_col_pos=$2
    local end_row_pos=$3
    local end_col_pos=$4
    local value=$5
    
    # Iterate + set over the range
    iterate_row=$start_row_pos
    iterate_col=$start_col_pos
    while (( ( iterate_row != end_row_pos ) || ( iterate_col != end_col_pos ) )); do
        if (( iterate_row > end_row_pos )); then
            iterate_row=$(( iterate_row - 1 ))
        elif (( iterate_row < end_row_pos )); then
            iterate_row=$(( iterate_row + 1 ))
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
    local row_pos=$1
    local col_pos=$2
    local value=$3

    # Determine if the move is valid. There are a few things we need to look at.
    # First, make sure the requested position is valid and available. We can use
    # board_get_pos to verify this.
    if [ $(board_get_pos $row_pos $col_pos) -eq "0" ]; then
        # Next, make sure the requested position is a legal move. We can use
        # board_is_legal_move to verify this.
        board_is_legal_move $row_pos $col_pos $value
        is_legal=$?
        if [ "$is_legal" -eq "0" ]; then
            # Everything is legal, set the new move!
            board_set_pos $row_pos $col_pos $value
         else
            # Move was not legal, bail out here
            return 1
        fi
    else
        return 1
    fi

    # Now we need to flip opponent pieces that were just surrounded 
    # Iterate over adjacent positions to the new move
    # BUG: On a range with pieces ordered 0 1 2 1 2, playing a 2 in the open
    #   position flips all the 1s along the range, not just the one bounded
    #   by the first 2.
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
    local row_pos=$1
    local col_pos=$2
    local value=$3
    local return_val=1 # Assume not legal until proven otherwise

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

                # TODO: The bounds on this loop go over by 1, fix this
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

# [set_available_moves]
# @param $1: Player # to get available moves for (1 or 2)
# @return: Nothing. Set one of the global variables, player1_available_moves or
#   player2_available_moves.
function set_available_moves {
    local player_num=$1
    local available_moves=( )
    local opponent_positions=( )

    # We know that any available move must be adjacent to an opponent piece.
    # Start by retrieving the list of opponent pieces.
    if [ "$player_num" = "1" ]; then
        opponent_positions=("${player2_pieces[@]}")
    elif [ "$player_num" = "2" ]; then
        opponent_positions=("${player1_pieces[@]}")
    fi

    # Now iterate over each opponent piece. Check all adjacent positions.
    for pos in "${opponent_positions[@]}"; do
        move_row=$(( ( pos / 8 ) + 1 ))
        move_col=$(( ( pos % 8 ) + 1 ))
        #printf "[set_available_moves] pos=$pos maps to row=$move_row, col=$move_col\n"
        for adj_row in `seq $(( move_row-1 )) $(( move_row+1 ))`; do
            for adj_col in `seq $(( move_col-1 )) $(( move_col+1 ))`; do
                if [ $(board_get_pos $adj_row $adj_col) = "0" ]; then
                    board_is_legal_move $adj_row $adj_col $player_num
                    is_legal=$?
                    #printf "[set_available_moves] for row=$adj_row, col=$adj_col, player_num=$player_num: is_legal=$is_legal\n"
                    if (( is_legal == 0 )); then
                        #printf "[set_available_moves] move row=$adj_row, col=$adj_col is legal!\n"
                        available_move_pos=$(( ((adj_row-1) * 8) + (adj_col - 1) ))
                        array_contains $available_move_pos "${available_moves[@]}"
                        if [ "$?" == "1" ]; then
                            available_moves+=($available_move_pos)
                        fi
                    fi
                fi
            done
        done
    done

    # Instead of returning an array (which is ugly in bash) set a global
    if [ "$player_num" = "1" ]; then
        player1_available_moves=("${available_moves[@]}")
    elif [ "$player_num" = "2" ]; then
        player2_available_moves=("${available_moves[@]}")
    fi
}

# [evaluate_available_moves]
# @param $1: Player # to evaluate available moves for (1 or 2)
# @return: The array element index that represents the best possible move.
function evaluate_available_moves {
    local player_num=$1
    local level_num=$2
    local available_moves=( )
    local results_filename="available_moves_$$"
    printf "[evaluate_available_moves_$$] called! player_num=$player_num, level_num=$level_num\n"

    # Copy the appropriate list of local moves into a local array
    if [ "$player_num" = "1" ]; then
        available_moves=("${player1_available_moves[@]}")
    elif [ "$player_num" = "2" ]; then
        available_moves=("${player2_available_moves[@]}")
    fi

    # Evaluate each of the available moves using a thread process
    for move in ${available_moves[@]}; do
        ./othello-bash.sh "thread" $player_num $move $results_filename $(( level_num - 1 )) ${board[*]} &
    done

    # Wait for all the thread processes to finish
    wait

    # Now iterate over the contents of the results file. Determine the value
    # of the best move, and the corresponding position
    local best_move=${available_moves[0]}
    local best_move_value=-64
    for result in `cat $results_filename`; do
        printf "[evaluate_available_moves_$$] level_num=$level_num, result=$result, best_move=$best_move, best_move_value=$best_move_value\n"
        while IFS='=' read -ra result_tokens; do
            local this_move=${result_tokens[0]}
            local this_move_value=${result_tokens[1]}
            if (( this_move_value > best_move_value )); then
                best_move=$this_move
                best_move_value=$this_move_value
            fi
        done <<< "$result"
    done

    # Delete the results file
    rm $results_filename

    # Return!
    printf "[evaluate_available_moves_$$] best_move=$best_move, best_move_value=$best_move_value\n"
    return $best_move
}

# [array_contains]
# @param $1: Value to search for
# @param $2: Array to look in
# @return: 0 is array contains value, 1 if not.
# @source: https://stackoverflow.com/questions/3685970/check-if-a-bash-array-contains-a-value
function array_contains {
    local e match="$1"  
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

# [array_remove]
# @param $1: Value to remove
# @param $2: Name of array to remove from, string
# @return: Nothing, assume success.
# @source: https://stackoverflow.com/questions/16860877/remove-element-from-array-shell
function array_remove {
    local match=$1
    local array_name=$2
    local new_array=( )
    #printf "[array_remove] match=$match, array_name=$array_name\n"

    # Bash sucks at removing elements from arrays + re-indexing the other
    # elements. This is a long-winded hack, can probably find a better way
    # to do this.
    if [ "$array_name" = "player1_pieces" ]; then
        for array_val in ${player1_pieces[@]}; do
            if (( array_val != match )); then
                new_array+=($array_val)
            fi
        done
        player1_pieces=( )
       for i in ${new_array[@]}; do 
            player1_pieces+=($i) 
        done;
    elif [ "$array_name" = "player2_pieces" ]; then
        for array_val in ${player2_pieces[@]}; do 
            if (( array_val != match )); then
                new_array+=($array_val)
            fi
        done
        player2_pieces=( )
        for i in ${new_array[@]}; do 
            player2_pieces+=($i) 
        done
    fi
}

# Start!
main $@