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
weighted_board=(
    120 -20 20  5   5   20  -20 120
    -20 -40 -5  -5  -5  -5  -40 -20
    20  -5  15  3   3   15  -5  20
    5   -5  3   3   3   3   -5  5
    5   -5  3   3   3   3   -5  5
    20  -5  15  3   3   15  -5  20
    -20 -40 -5  -5  -5  -5  -40 -20
    120 -20 20  5   5   20  -20 120
)
player1_pieces=( ) # set later using set_player_pieces
player2_pieces=( ) # set later using set_player_pieces
player1_available_moves=( ) # set later using set_available_moves
player2_available_moves=( ) # set later using set_available_moves

# [main]
# @param $1: Process type. Can be "process", "thread" (default "process")
function main() {

    # Command line arguments. Only process the first one here to determine
    # if this is a process or a process thread.
    process_type="process"
    if [ ! -z $1 ]; then process_type=$1; fi

    # If process thread, call the thread handler function which will deal
    # with the rest of the command line arguments. Once that is complete, exit.
    if [ "$process_type" = "thread" ]; then
        thread $@
        exit
    fi

    # Delete garbage
    rm -rf available_moves*

    # Setup the initial game state
    set_player_pieces  
    set_available_moves 1
    set_available_moves 2
    game_state="player1_turn" # "player1_turn" for human start, "player2_turn" for computer start.
    minmax_depth=3 # Set this to 1 on laptops and slower desktops!!


    # Main process loop!
    while [ $game_state != "game_over" ]; do

        # Show the current state of the board
        board_show
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
                sleep 1
            else
                # Move was successful. Evaluate player 2 available moves. 
                # If they have none, check if game is over. 
                set_available_moves 2
                if [ "${#player2_available_moves[@]}" = "0" ]; then
                    set_available_moves 1
                    if [ "${#player1_available_moves[@]}" = "0" ]; then
                        game_state="game_over"
                    else
                        printf "\n*** Player 2 has no available moves! Passing. ***\n"
                    fi
                # Otherwise, player 2 turn.
                else
                    game_state="player2_turn"
                fi
            fi

        # Player 2 (computer) turn
        elif [ $game_state = "player2_turn" ]; then
            printf "Player 2 turn. Computer is thinking...\n"

            player2_move_start_time=`date +%s`

            # Strategy 1: Choose a move at random
            #random_move_index=$(( RANDOM % ${#player2_available_moves} ))
            #player2_move=${player2_available_moves[$random_move_index]}

            # Strategy 2: Evaluate the best move using recursive minmax tree  
            # to depth $minmax_depth. 
            # Result is a '=' delimited string: move_pos=move_value
            player2_minmax_move_result=$(evaluate_available_moves 2 $minmax_depth)
            IFS='=' read -a result_tokens <<< "$player2_minmax_move_result"
            player2_move_pos=$(( ${result_tokens[0]} ))

            # Play the best move determined by our chosen strategy
            player2_move_row=$(( ( player2_move_pos / 8 ) + 1 ))
            player2_move_col=$(( ( player2_move_pos % 8 ) + 1 ))
            board_play_move $player2_move_row $player2_move_col 2
            printf "Player 2 played at row $player2_move_row, col $player2_move_col (array pos $player2_move_pos).\n"

            # Show some timing information
            player2_move_end_time=`date +%s`
            player2_move_time=$(( player2_move_end_time - player2_move_start_time ))
            printf "Player 2 decision took $player2_move_time seconds.\n"

            # Move was successful. Evaluate player 1 available moves. If
            # they have none, check if game is over. Otherwise, player 2 turn.
            set_available_moves 1
            if [ "${#player1_available_moves[@]}" = "0" ]; then
                set_available_moves 2
                if [ "${#player2_available_moves[@]}" = "0" ]; then
                    game_state="game_over"
                else
                    printf "\n*** Player 1 has no more available moves! ***\n"
                fi
            else
                game_state="player1_turn"
            fi
        fi

    done

    # Game over! Figure out who won.
    printf "\nGame over!\n\n"
    board_show
    player1_score=${#player1_pieces[@]}
    player2_score=${#player2_pieces[@]}
    printf "Player 1 has $player1_score pieces\n"
    printf "Player 2 has $player2_score pieces\n"
    if (( player1_score > player2_score )); then
        printf "\nPlayer 1 wins!\n"
    else
        printf "\nPlayer 2 wins!\n"
    fi
}

# [thread]
# @description: Main control loop for "thread" processes, which are not
#   technically threads but are being used in a similar way. Runs a minmax
#   search by calling evaluate_available_moves, which recursively calls up more
#   thread subprocesses.
function thread {
    local player_num=$2
    local suggested_move=$3
    local results_filename=$4
    local level_num=$5
    local move_result
    local opponent_num
    
    # Determine some other useful local variables
    if [ "$player_num" = "1" ]; then opponent_num=2; else opponent_num=1; fi
    local suggested_move_row=$(( ( suggested_move / 8 ) + 1 ))
    local suggested_move_col=$(( ( suggested_move % 8 ) + 1 ))

    # Set the state of the game (board, player1_pieces, player2_pieces, current
    # player available moves) based on remaining command-line arguments
    player1_pieces=( )
    player2_pieces=( )
    shift 5
    for index in `seq 0 63`; do
        board[$index]=$1
        if [ "$1" = "1" ]; then player1_pieces+=($index); fi
        if [ "$1" = "2" ]; then player2_pieces+=($index); fi
        shift
    done
    set_available_moves $player_num

    # Play the suggested move
    board_play_move $suggested_move_row $suggested_move_col $player_num
    
    # Recursively determine the score using evaluate_available_moves!
    # Right now, score is difference in number of pieces between the current 
    #   player ($player_num) vs. opponent
    # TODO: Better way to return these values than a disk write?
    if (( level_num >= 1 )); then
        set_available_moves $opponent_num
        best_move_result=$(evaluate_available_moves $opponent_num $level_num)
        IFS='=' read -a result_tokens <<< "$best_move_result"
        move_result=$(( ${result_tokens[1]} ))
    else
        # As we traverse up, we're always looking for the best result for 
        # player2 (computer).
        
        # Scoring strategy 1: difference in player pieces on the board
        # move_result=$(( ${#player2_pieces[@]} - ${#player1_pieces[@]} ))

        # Scoring strategy 2: difference in weighted player pieces
        move_result=0
        for pos in ${player2_pieces[@]}; do
            move_result=$(( move_result + weighted_board[pos] ));
        done
        for pos in ${player1_pieces[@]}; do
            move_result=$(( move_result - weighted_board[pos] ));
        done

    fi
    #dprintf "[thread_$$] player_num=$player_num, level_num=$level_num, opponent_num=$opponent_num, suggested_move=$suggested_move ($suggested_move_row, $suggested_move_col), results_filename=$results_filename, move_result=$move_result\n"
    
    # Output results
    echo $suggested_move=$move_result >> $results_filename
}

# [board_show]
# @return: Nothing. Just output the board to stdout.
function board_show {
    printf "   \n    1 2 3 4 5 6 7 8"
    printf "   \n  +-----------------+\n"
    for i in `seq 0 63`; do
        if (( $i % 8 == 0)); then printf "$(( (i/8) + 1 )) |"; fi
        printf " %d" ${board[$i]}
        if (( $i % 8 == 7)); then printf " | $(( (i+1) / 8 ))"; fi
        if (( ($i + 1) % 8 == 0 && $i != 63 )); then printf "\n"; fi
    done
    printf "   \n  +-----------------+\n    1 2 3 4 5 6 7 8\n\n"
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
    board[$array_pos]=$new_pos_value

    if (( new_pos_value == 1 )); then
        array_contains $array_pos "${player1_pieces[@]}"
        if [ "$?" = "1" ]; then
            player1_pieces+=($array_pos)
            if [ "$old_pos_value" = "2" ]; then
                array_remove $array_pos "player2_pieces"
            fi
        fi
    elif (( new_pos_value == 2 )); then
        array_contains $array_pos "${player2_pieces[@]}"
        if [ "$?" = "1" ]; then
            player2_pieces+=($array_pos)
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
# @description: Play a move. Verifies the requested position is a valid move
#   space. If it is, set the position, then flip all opponent pieces that 
#   were surrounded by the new move.
# @param $1: Row position of the new move (1 to 8)
# @param $2: Col position of the new move (1 to 8)
# @param $3: Player number, also the value to set.
# @return: 0 if the move was played successfully, 1 if not.
function board_play_move {
    local row_pos=$1
    local col_pos=$2
    local player_num=$3

    # Determine if the move is valid. Just check if the move is in the player's
    # available moves array; assume all moves in there are legal and valid.
    # Important, also assume the available moves arrays are up to date!
    move_pos=$(( ((row_pos-1) * 8) + (col_pos - 1) ))
    if [ "$player_num" = "1" ]; then
        array_contains $move_pos "${player1_available_moves[@]}"
    elif [ "$player_num" = "2" ]; then
        array_contains $move_pos "${player2_available_moves[@]}"
    fi

    is_legal=$?
    if [ "$is_legal" -eq "0" ]; then
        # Everything is legal, set the new move!
        board_set_pos $row_pos $col_pos $player_num
    else
        # Move was not legal, bail out here
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
            if (( player_num + this_pos_value == 3 )); then

                # Now traverse the matrix in the direction of the opponent
                # piece. Continue until we either:
                # 1. Hit a 0 (empty), in which case the move is not valid.
                # 2. Hit the edge of the board, in which case the move is not valid
                # 3. Hit one of our own pieces, in which case the move is valid
                scan_row=$row
                scan_col=$col
                row_diff=$(( row - row_pos ))
                col_diff=$(( col - col_pos ))

                while (( scan_row >= 1 && scan_row <= 8 && scan_col >= 1 && scan_col <= 8 )); do
                    scan_val=$(board_get_pos $scan_row $scan_col)
                    if [ "$scan_val" -eq "0" ]; then
                        break
                    elif [ "$scan_val" -eq "$player_num" ]; then
                        board_set_range $row_pos $col_pos $scan_row $scan_col $player_num
                        break
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
# @param $1: Board array position of the space to verify (0 to 63)
# @param $2: Value to verify is legal.
# @return: 0 if the move is legal, 1 if not.
function board_is_legal_move {
    local array_pos=$1
    local value=$2
    local return_val=1 # Assume not legal until proven otherwise

    # Get an array of surrounding moves
    local adjacent_positions=( 
        $(( array_pos - 9 )) $(( array_pos - 8 )) $(( array_pos - 7 ))
        $(( array_pos - 1 ))                      $(( array_pos + 1 ))
        $(( array_pos + 7 )) $(( array_pos + 8 )) $(( array_pos + 9 ))
    )
    
    # Iterate over adjacent positions to the requested position
    for adj_pos in ${adjacent_positions[@]}; do

        adj_pos_value=${board[$adj_pos]}

        # Check if this position is adjacent to an opponent. If so, their
        # position values (1, 2) will add up to 3.
        if (( value + adj_pos_value == 3 )); then

            array_pos_row=$(( ( array_pos / 8 ) + 1 ))
            array_pos_col=$(( ( array_pos % 8 ) + 1 ))
            adj_pos_row=$(( ( adj_pos / 8 ) + 1 ))
            adj_pos_col=$(( ( adj_pos % 8 ) + 1 ))
            
            # Now traverse the matrix in the direction of the opponent
            # piece we just found. Continue until:
            # 1. Hit a 0 (empty): move is not valid.
            # 2. Hit the edge of the board: move is not valid
            # 3. Hit one of our own pieces: move is valid
            row_diff=$(( adj_pos_row - array_pos_row ))
            col_diff=$(( adj_pos_col - array_pos_col ))
            scan_row=$(( array_pos_row + row_diff ))
            scan_col=$(( array_pos_col + col_diff ))

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

    # Return as value
    return $return_val
}

# [set_available_moves]
# @param $1: Player # to set available moves for (1 or 2)
# @return: Nothing. Set one of the global variables, player1_available_moves or
#   player2_available_moves.
function set_available_moves {
    local player_num=$1
    local available_moves=( )

    # Iterate over every square in the board. For every unoccupied square, check
    # if that represents a legal move.
    for pos in `seq 0 63`; do
        pos_val=${board[$pos]}
        if [ "$pos_val" = "0" ]; then
            board_is_legal_move $pos $player_num
            is_legal=$?
            # If this is a legal move, add it!
            if (( is_legal == 0 )); then
                available_moves+=($pos)
            fi
        fi
    done

    # Instead of returning an array (which is ugly in bash) set a global
    if [ "$player_num" = "1" ]; then
        player1_available_moves=("${available_moves[@]}")
    elif [ "$player_num" = "2" ]; then
        player2_available_moves=("${available_moves[@]}")
    fi
}

# [set_player_pieces]
# @return: Nothing. Set both global variables, player1_pieces and player2_pieces.
function set_player_pieces {
    player1_pieces=( )
    player2_pieces=( )
    for index in `seq 0 63`; do
        if [ "${board[$index]}" = "1" ]; then player1_pieces+=($index); fi
        if [ "${board[$index]}" = "2" ]; then player2_pieces+=($index); fi
        shift
    done
}

# [evaluate_available_moves]
# @param $1: Player # to evaluate available moves for (1 or 2)
# @param $2: This move's current level in the minmax tree.
# @return: A string formatted as "$best_move_pos=$best_move_result"
function evaluate_available_moves {
    local player_num=$1
    local level_num=$2
    
    local available_moves=( )
    local minmax_val
    local results_filename="available_moves_$$"
    local return_val

    # Copy the appropriate list of local moves into a local array
    if [ "$player_num" = "1" ]; then
        available_moves=("${player1_available_moves[@]}")
    elif [ "$player_num" = "2" ]; then
        available_moves=("${player2_available_moves[@]}")
    fi
    
    #3dprintf "\n[evaluate_available_moves_$$] player_num=$1, level_num=$2, p$player_num available_moves=(${available_moves[*]})\n"
    # Recursively evaluate each of the available moves using a thread process
    for move in ${available_moves[@]}; do
        ./othello-bash.sh "thread" $player_num $move $results_filename $(( level_num - 1 )) ${board[*]} &
    done

    # Wait for all the thread processes to finish
    wait

    # Set if we are looking for a min-value or a max-value
    local best_move_value
    if (( player_num % 2 == 0 )); then
        minmax_val="max"
        best_move_value=-10000
    else
        minmax_val="min"
        best_move_value=10000
    fi

    # Now iterate over the contents of the results file. This is where the min-max
    # magic happens. When $level_num is odd, we want to return the maximum
    # score. When $level_num is even, return the minimum score.
    # Set the return value as $best_move=$best_move_value
    local return_val
    for result in `cat $results_filename`; do
        while IFS='=' read -ra result_tokens; do
            local this_move_value=${result_tokens[1]}
            if [ "$minmax_val" = "max" ]; then
                if (( this_move_value > best_move_value )); then
                    best_move_value=$this_move_value
                    return_val=$result
                fi
            elif [ "$minmax_val" = "min" ]; then
                if (( this_move_value < best_move_value )); then
                    best_move_value=$this_move_value
                    return_val=$result
                fi
            fi
        done <<< "$result"
        #dprintf "[evaluate_available_moves_$$] player_num=$player_num, level_num=$level_num, minmax_val=$minmax_val, result: $result, best_move_value=$best_move_value, return_val=$return_val\n"
    done

    # Delete the results file
    rm $results_filename

    # Return!
    echo $return_val
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

    # Bash sucks at removing elements from arrays + re-indexing the other
    # elements. Is there a better way to do this?
    if [ "$array_name" = "player1_pieces" ]; then
        for array_val in ${player1_pieces[@]}; do
            if (( array_val != match )); then new_array+=($array_val); fi
        done
        player1_pieces=( )
        for i in ${new_array[@]}; do player1_pieces+=($i); done
    elif [ "$array_name" = "player2_pieces" ]; then
        for array_val in ${player2_pieces[@]}; do 
            if (( array_val != match )); then new_array+=($array_val); fi
        done
        player2_pieces=( )
        for i in ${new_array[@]}; do player2_pieces+=($i); done
    fi
}

# [dprintf]
# @description: Debug printf to stderr. Used to debug functions that return 
#   values by stdout.
# @param $1: String to output to stderr
# @param $2: Any arguments that need to be converted
# @return: Nothing, assume success.
function dprintf {
    local string=$1
    shift
    local args=$@
    >&2 printf "$string" ${args[*]}
}


# Start!
main $@
