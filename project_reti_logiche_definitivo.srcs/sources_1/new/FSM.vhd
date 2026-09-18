library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is 
port (  
    i_clk   : in std_logic; 
    i_rst   : in std_logic; 
    i_start : in std_logic;  
    i_task_id : in std_logic_vector(5 downto 0); 
    i_task_priority : in std_logic_vector(1 downto 0); 
    i_op : in std_logic_vector(1 downto 0); 
    o_done : out std_logic; 
    o_task_id  : out std_logic_vector(5 downto 0); 
    o_mem_addr : out std_logic_vector(15 downto 0); 
    i_mem_data : in std_logic_vector(7 downto 0); 
    o_mem_data : out std_logic_vector(7 downto 0); 
    o_mem_we   : out std_logic; 
    o_mem_en   : out std_logic 
); 
end project_reti_logiche; 

architecture fsm_arch of project_reti_logiche is
    type S is (RESET, IDLE, READ_COUNT, WAIT_COUNT, OP_11, OP_00_READ, OP_00_WRITE, OP_01_READ, OP_01_WRITE, OP_01_OUT, OP_10, OP_10_SHIFT_READ, OP_10_SHIFT_WRITE, OP_10_INSERT, UPDATE_COUNT, DONE); 
    -- states
    signal curr_state : S; 
    signal next_state : S;
    
    -- internal registers
    signal r_op: std_logic_vector (1 downto 0);
    signal r_task_count: integer range 0 to 63;
    signal r_index: integer range 0 to 63;
    signal r_first: std_logic_vector(5 downto 0);
    signal r_insert_pos: integer range 0 to 63;
    
    -- auxiliary register
    signal next_op: std_logic_vector (1 downto 0);
    signal next_index: integer range 0 to 63;
    signal next_count: integer range 0 to 63;
    signal next_first: std_logic_vector(5 downto 0);
    signal next_insert_pos: integer range 0 to 63;
    
    constant MAX_TASKS : integer := 63;
    
begin 

sequence_proc: process(i_clk, i_rst)
begin
    if i_rst = '1' then 
        curr_state <= RESET; 
        r_op <= (others => '0'); 
        r_task_count <= 0; 
        r_index <= 0; 
        r_first <= (others => '0'); 
        r_insert_pos <= 0; 
        --r_task_id <= (others => '0'); 
        --r_task_priority <= (others => '0'); 
    elsif rising_edge(i_clk) then
        curr_state <= next_state; 
        r_op <= next_op; 
        r_task_count <= next_count; 
        r_index <= next_index; 
        r_first <= next_first; 
        r_insert_pos <= next_insert_pos; 
        --r_task_id <= i_task_id; 
        --r_task_priority <= i_task_priority;    
    end if; 
end process;

comb_proc: process(curr_state, i_start, i_mem_data, i_task_id, i_task_priority, i_op, r_op, r_index, r_task_count, r_first, r_insert_pos )--, r_task_id,r_task_priority ) 
begin
    -- DEFAULT
    o_mem_en <= '0';
    o_mem_we <= '0';
    o_mem_addr <= (others => '0');
    o_mem_data <= (others => '0');
    o_done <= '0';
    o_task_id <= (others => '0');
    -- DEFAULT NEXT
    next_state <= curr_state;
    next_op <= r_op;
    next_index <= r_index;
    next_count <= r_task_count;
    next_first <= r_first;
    next_insert_pos <= r_insert_pos;
    
case curr_state is
            when RESET => 
                o_mem_en <= '1';
                o_mem_we <= '1';
                o_mem_addr <= (others => '0');
                o_mem_data <= (others => '0');
                o_done <= '1';
                next_state <= IDLE;
            when IDLE =>
                if i_start = '1' then
                    next_state <= READ_COUNT;
                    next_op  <= i_op;
                end if;
            when READ_COUNT =>
                o_mem_en <= '1';
                o_mem_we <= '0';
                if(r_op = "11") then
                    next_state <= OP_11;
                elsif (r_op = "01" or r_op = "00" or r_op = "10") then
                    next_state <= WAIT_COUNT;
                end if;
            when WAIT_COUNT =>            
                next_count <= to_integer(unsigned(i_mem_data));
                next_insert_pos <= 0; 
                if(r_op = "00") then
                    if (to_integer(unsigned(i_mem_data)) = 0) then
                        next_state <= DONE;
                    else
                        next_index <= 1;
                        next_state <= OP_00_READ;
                    end if;
                elsif (r_op = "01")then
                    if (to_integer(unsigned(i_mem_data)) = 0) then
                        next_first <= (others => '0');
                        next_state <= OP_01_OUT;
                    else
                        next_index <= 1;
                        next_state <= OP_01_READ;
                    end if;
                elsif(r_op = "10") then
                    if (to_integer(unsigned(i_mem_data)) = 0) then
                        next_insert_pos <= 1;
                        next_state <= OP_10_insert;
                    elsif (to_integer(unsigned(i_mem_data)) >= MAX_TASKS) then
                        next_state <= DONE;  -- lista piena, ignora l'inserimento
                    else
                        next_index <= 1;
                        next_state <= OP_10;
                    end if;
                end if; 
            when OP_11 =>
                o_mem_en <= '1';
                o_mem_we <= '1';
                o_mem_addr <= (others => '0');
                o_mem_data <= (others => '0');
                next_state <= DONE;
            when OP_00_READ =>
                 o_mem_en   <= '1';
                 o_mem_we   <= '0';
                 o_mem_addr <= std_logic_vector(to_unsigned(r_index, 16));
                 next_state <= OP_00_WRITE;
            when OP_00_WRITE =>
                  o_mem_en   <= '1';
                  o_mem_we   <= '1';
                  o_mem_addr <= std_logic_vector(to_unsigned(r_index, 16));
                  if i_mem_data(1 downto 0) = "11" then 
                       o_mem_data <= i_mem_data(7 downto 2) & "11";
                  else
                       o_mem_data <= i_mem_data(7 downto 2) & std_logic_vector(unsigned(i_mem_data(1 downto 0)) + 1);
                  end if;
                  if r_index >= r_task_count then 
                       next_state <= DONE;
                  else
                       next_index <= r_index + 1;
                       next_state <= OP_00_READ;
                  end if;
            when OP_01_READ =>
                  o_mem_en   <= '1';
                  o_mem_we   <= '0'; 
                  o_mem_addr <= std_logic_vector(to_unsigned(r_index, 16));
                  if r_index = 1 then 
                       next_index <= 2;
                       next_state <= OP_01_READ; 
                  else
                      if r_index = 2 then
                         next_first <= i_mem_data(7 downto 2);
                      end if;
                         next_state <= OP_01_WRITE;
                  end if;
            when OP_01_WRITE =>
                   o_mem_en   <= '1';
                   o_mem_we   <= '1';
                   o_mem_addr <= std_logic_vector(to_unsigned(r_index - 1, 16));
                   o_mem_data <= i_mem_data; 
                   if r_index = r_task_count +1  then
                       next_state <= UPDATE_COUNT;
                   else
                       next_index <= r_index + 1;
                       next_state <= OP_01_READ;
                   end if;
            when OP_01_OUT =>
                if(r_task_count = 0) then 
                    o_task_id <= (others => '0');
                else 
                    o_task_id <= r_first;
                end if;
                o_done <= '1';
                next_state <= DONE;
            when OP_10 =>
                o_mem_en <= '1';
                o_mem_we <= '0';
                o_mem_addr <= std_logic_vector(to_unsigned(r_index, 16));
                if (r_index > r_task_count) then
                    next_insert_pos <= r_task_count + 1; 
                    next_state <= OP_10_INSERT; 
                else
                    next_state <= OP_10_SHIFT_READ; 
                end if;
            when OP_10_SHIFT_READ =>
                 o_mem_en   <= '1';
                 o_mem_we   <= '0'; 
                 o_mem_addr <= std_logic_vector(to_unsigned(r_index, 16));
                 if(r_insert_pos > 0) then
                    next_state <= OP_10_SHIFT_WRITE;   
                 elsif (unsigned(i_mem_data(1 downto 0)) > unsigned(i_task_priority)) then
                    next_insert_pos <= r_index; 
                    next_index <= r_task_count; 
                    next_state <= OP_10_SHIFT_READ; 
                 else    
                    next_index <= r_index + 1; 
                    next_state <= OP_10; 
                 end if;            
            when OP_10_SHIFT_WRITE =>
                 o_mem_en   <= '1';
                 o_mem_we   <= '1';
                 o_mem_addr <= std_logic_vector(to_unsigned(r_index + 1, 16));
                 o_mem_data <= i_mem_data; 
                 if r_index = r_insert_pos then
                     next_state <= OP_10_INSERT;
                 else
                     next_index <= r_index - 1;
                     next_state <= OP_10_SHIFT_READ;
                 end if;
            when OP_10_INSERT =>
                o_mem_en   <= '1';
                o_mem_we   <= '1';
                o_mem_addr <= std_logic_vector(to_unsigned(r_insert_pos, 16));
                o_mem_data <= i_task_id & i_task_priority;
                next_state <= UPDATE_COUNT;
            when UPDATE_COUNT =>
                o_mem_en   <= '1';
                o_mem_we   <= '1';
                o_mem_addr <= (others => '0'); 
                if (r_op = "10") then 
                    o_mem_data <= std_logic_vector(to_unsigned(r_task_count + 1, 8));
                    next_state <= DONE;
                elsif (r_op = "01") then
                    o_mem_data <= std_logic_vector(to_unsigned(r_task_count - 1, 8));
                    next_state <= OP_01_OUT;
                end if;
            when DONE =>
                o_done <= '1';
                if i_start = '0' then
                    next_state <= IDLE;
                end if;
            when others =>
                next_state <= RESET;
    end case;
end process; 
end architecture; 

            
        
                    
                    
