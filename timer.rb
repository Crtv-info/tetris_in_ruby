module Timer
    def set_frame_rate(time)
        @frame_rate = time
    end

    def timer(join: false, sleep: true)
        @th = Thread.new {
            loop do
                yield
                sleep 60.0/@frame_rate  if sleep
            end
        }
        @th.join  if join
    end

    def exit
        @th.kill
    end
    
    module_function :set_frame_rate, :timer, :exit
end