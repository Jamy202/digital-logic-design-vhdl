library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity testbench_1 is 
end testbench_1; 

architecture arch_tb of testbench_1 is

    component project_reti_logiche 
    port(
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
   end component;
   
   component rams_sp_wf
       port(
         clk  : in  std_logic;
         we   : in  std_logic;
         en   : in  std_logic;
         addr : in  std_logic_vector(15 downto 0);
         di   : in  std_logic_vector(7 downto 0);
         do   : out std_logic_vector(7 downto 0)
       );
   end component;
   
      signal i_clk : std_logic := '0'; 
      signal i_rst : std_logic := '0'; 
      signal i_start : std_logic := '0';  
      signal i_task_id : std_logic_vector(5 downto 0) := (others => '0'); 
      signal i_task_priority : std_logic_vector(1 downto 0) := (others => '0'); 
      signal i_op : std_logic_vector(1 downto 0) := (others => '0'); 
      signal o_done : std_logic; 
      signal o_task_id  : std_logic_vector(5 downto 0); 
      signal o_mem_addr : std_logic_vector(15 downto 0); 
      signal i_mem_data : std_logic_vector(7 downto 0); 
      signal o_mem_data : std_logic_vector(7 downto 0); 
      signal o_mem_we   : std_logic; 
      signal o_mem_en   : std_logic;
      
 begin
 
    UUT: project_reti_logiche port map(
    --porta del componente => segnale del testbench
    i_clk => i_clk, 
    i_rst => i_rst, 
    i_start => i_start, 
    i_task_id => i_task_id, 
    i_task_priority => i_task_priority, 
    i_op => i_op, 
    o_done => o_done,   
    o_task_id => o_task_id, 
    o_mem_addr => o_mem_addr,
    i_mem_data => i_mem_data, 
    o_mem_data => o_mem_data, 
    o_mem_we => o_mem_we, 
    o_mem_en => o_mem_en
    ); 
    
    MEM: rams_sp_wf port map(
        clk  => i_clk,
        we   => o_mem_we,
        en   => o_mem_en,
        addr => o_mem_addr,
        di   => o_mem_data,
        do   => i_mem_data
    );
    
    clk_process: process
    begin
        i_clk <= '0'; 
        wait for 5 ns; 
        i_clk <= '1'; 
        wait for 5 ns; 
    end process;   
    test: process
    begin
        --reset: 
           i_rst <= '1'; 
           wait for 20 ns; 
           i_rst <= '0'; 
           --wait until o_done = '0'; 
           wait for 20 ns;  
        -- test 1: se ho una lista vuota, me la inserisce come prima nella ram
           i_op <= "10"; 
           i_task_id <= "000011"; 
           i_task_priority <= "10"; 
           i_start <= '1'; 
           wait until o_done = '1';
           i_start <= '0'; 
           --wait until o_done = '0';  
           wait for 30 ns;
           wait; 
    end process;    
end architecture;  
        
         