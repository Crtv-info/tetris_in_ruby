require 'io/console'
require 'timeout'
require './timer'

class Tetris
    def initialize(*size)
        raise ArgumentError if !size[0].even? || size[0] < 4
        @size = size
        @_tag_speed = Struct.new("Speed", :init, :max, :rate)
        @_tag_panel = Struct.new("Panel", :width, :height, :block)
        @_tag_state = Struct.new("Now_State", :x, :y, :block)
        @state =@_tag_speed.new(70.0, 1000.0, 0.005)
        @field = @_tag_panel.new(*@size, [])
        @field.block = Array.new(@size[0]*@size[1], 0).each_slice(@size[0]).to_a
        @now = @_tag_state.new(0, 0)
        @buffer = Array.new(4)
        @next = rand(0...7)
        @score = 0
        @update = true
        @colors = [0] + (41..47).to_a
        setup
    end

    def setup
        @blocks = [[[0, 0, 0, 0],
                    [1, 1, 1, 1],
                    [0, 0, 0, 0],
                    [0, 0, 0, 0]
                   ],
                   [[0, 0, 0, 0],
                    [0, 2, 2, 0],
                    [0, 2, 2, 0],
                    [0, 0, 0, 0]
                   ],
                   [[0, 0, 0, 0],
                    [3, 3, 3, 0],
                    [0, 3, 0, 0],
                    [0, 0, 0, 0]
                   ],
                   [[0, 0, 0, 0],
                    [4, 4, 0, 0],
                    [0, 4, 4, 0],
                    [0, 0, 0, 0]
                   ],
                   [[0, 0, 0, 0],
                    [0, 5, 5, 0],
                    [5, 5, 0, 0],
                    [0, 0, 0, 0]
                   ],
                   [[0, 0, 0, 0],
                    [6, 6, 6, 0],
                    [0, 0, 6, 0],
                    [0, 0, 0, 0]
                   ],
                   [[0, 0, 0, 0],
                    [7, 7, 7, 0],
                    [7, 0, 0, 0],
                    [0, 0, 0, 0]
        ]]
    end

    def exec
        system('clear')
        draw_wall
        create_block
        fall_timer
        while @update
            print_board
            case read_key speed(@score)
            when '→' then
                move_block(1, 0)
                redo
            when '←' then
                move_block(-1, 0)
                redo
            when '↓' then
                if !move_block(0, 1)
                    create_block
                end
                redo
            when '↑' then
                rotation_block
            when ' ' then
                while move_block(0, 1); end
                if !delete_line
                    create_block
                end
            end
            delete_line
        end
        game_end
    end

    private

    def print_board
        @field.height.times do |y|
            if y == 0
                print_remark
            end
            print "\e[1C"
            @field.width.times do |x|
                printf("\e[%dm  \e[0m", @field.block[y][x])
            end
            print("\n\e[#{@field.width*2+1}D")
        end
        print("\e[#{@field.height}A")
        STDOUT.flush
    end

    def print_remark
        print("\e[#{@field.width*2+7}C Score: #{@score}\n")
        print("\e[#{@field.width*2+7}C Frame: #{(60.0/speed(@score)).round(2)}\n\n\n\n")
        print("\e[#{@field.width*2+7}C Next Block\n\n")
        4.times do |i|
            print("\e[#{@field.width*2+7}C ")
            4.times do |j|
                if @blocks[@next][i][j] != 0
                    printf("\e[%dm  \e[0m", @colors[@blocks[@next][i][j]])
                else
                    print("\e[0m  ")
                end
            end
            print("\n\e[8D")
        end
        print("\e[11A\e[#{@field.width*30}D")
    end

    def draw_wall(wall_size=4, wall_col=40)
        wall = Array.new((@field.width+2)*(@field.height+wall_size+1)).each_slice((@field.width+2)).to_a
        wall.length.times { |i|
            wall[i].length.times { |j| wall[i][j] = {state: true, n: 2} }
            if i >= wall_size && i < @field.height+wall_size
                wall[i][1..@field.width] = [{state: false, n: 2}] * @field.width
            elsif i != @field.height+wall_size
                wall[i][(@field.width/2-1)..(@field.width/2+2)] = [{state: false, n: 2}] * 4
            end
        }
        wall.length.times do |y|
            wall[y].length.times do |x|
                wall[y][x][:n] = 1  if x == 0 || x == @field.width+1
                if wall[y][x][:state]
                    print "\e[#{wall_col}m#{" "*wall[y][x][:n]}\e[0m"
                else
                    print "#{" "*wall[y][x][:n]}"
                end
            end
            print("\n")
        end
        print("\e[#{wall.length-wall_size}A\e[?25l")
    end

    def create_block
        @now.x = @field.width/2-2
        @now.y = 0
        @update = false  if game_over?(@next)
        @now.block = @blocks[@next]
        @next = rand(0...7)
        i = 0
        4.times do |y|
            4.times do |x|
                if @now.block[y][x]!=0
                    @field.block[y][x+@now.x] = @colors[@now.block[y][x]]
                    @buffer[i] = @_tag_state.new(x + @now.x, y)
                    @buffer[i].block = @colors[@now.block[y][x]]
                    i += 1
                end
            end
        end
    end

    def move_block(x, y)
        clear_block
        if can_put?(x, y)
            4.times do |i|
                @field.block[@buffer[i].y+y][@buffer[i].x+x] = @buffer[i].block
                @buffer[i].x += x
                @buffer[i].y += y
            end
            @now.x += x
            @now.y += y
            return true
        else
            4.times { |i| @field.block[@buffer[i].y][@buffer[i].x] = @buffer[i].block }
            false
        end
    end

    def fall_timer
        Timer::timer(sleep: false) {
            if !move_block(0, 1)
                create_block
            end
            sleep speed(@score)
        }
    end

    def rotation_block
        clear_block
        tmp = []
        4.times do |y|
            tmp << []
            4.times do |x|
                tmp[y] << @now.block[y][x]
            end
        end
        flag = true
        4.times do |y|
            4.times do |x|
                if @field.block[y+@now.y][x+@now.x]!=0 && tmp[3-x][y]!=0 || x+@now.x < 0
                    flag = false
                end
            end
        end
        if flag
            4.times do |y|
                4.times do |x|
                    @now.block[y][x] = tmp[3-x][y]
                end
            end
            i = 0
            4.times do |y|
                4.times do |x|
                    if @now.block[y][x]!=0
                        @buffer[i] = @_tag_state.new(x + @now.x, y + @now.y)
                        @buffer[i].block = @colors[@now.block[y][x]]
                        i += 1
                    end
                end
            end
        end
        move_block(0, 0)
        setup
    end

    def clear_block
        4.times { |i| @field.block[@buffer[i].y][@buffer[i].x] = 0 }
    end

    def delete_line
        lines = []
        flag = true
        @field.height.times do |y|
            @field.width.times do |x|
                if @field.block[y][x] == 0
                    flag = false
                end
            end
            if flag
                lines <<  y
            end
            flag= true
        end
        return false  if lines.length == 0
        lines.each do |line|
            line.downto(1) do |y|
                @field.width.times do |x|
                    @field.block[y][x] = @field.block[y-1][x]
                end
            end
            @score += 1
        end
        Timer::exit
        fall_timer
        create_block
        true
    end

    def delete_field
        @field.height.times do |y|
            @field.width.times do |x|
                @field.block[y][x] = 0
            end
        end
    end

    def can_put?(x, y)
        begin
            4.times do |i|
                if @field.block[@buffer[i].y+y][@buffer[i].x+x] != 0
                    return false
                end
                if @buffer[i].x+x < 0
                    return false
                end
            end
        rescue => exception
            return false
        end
        true
    end

    def game_over?(n)
        4.times do |y|
            4.times do |x|
                if @blocks[n][y][x]!=0 && @field.block[y+@now.y][x+@now.x]!=0
                    return true
                end
            end
        end
        false
    end

    def game_end
        @field.height.times do |y|
            @field.width.times do |x|
                if @field.block[y][x] != 0
                    @field.block[y][x] = 41
                end
            end
        end
        print_board
        sleep 2
        @field.height.times do |y|
            @field.width.times do |x|
                @field.block[y][x] = 0
            end
            clear_block
            print_board
            sleep 0.05
        end
        system('clear')
    end

    def speed(score)
        60 / (@state.max / (1.0+((@state.max/@state.init-1.0) * (Math::E**(-@state.rate*score)))))
    end

    def read_key(timeout)
        begin
            Timeout.timeout(timeout) {
                cmd = {A: '↑', B: '↓', C: '→', D: '←'}
                while (key = STDIN.getch) != "\C-c"
                    if key == "\e"
                        second_key = STDIN.getch
                        if second_key == "["
                            key = STDIN.getch
                            key = cmd[key.intern] || "esc: [#{key}"
                        end
                    end
                    return key  if cmd.values.include?(key) || key == " "
                end
                system('clear')
                exit!
            }
        rescue Timeout::Error
            nil
        end
    end
end

if __FILE__ == $0
    tetris = Tetris.new(12, 15)
    tetris.exec
end