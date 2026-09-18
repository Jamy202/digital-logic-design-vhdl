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
    
    --- non usati da controllare poi 
    --signal r_task_id: std_logic_vector(5 downto 0);
    --signal r_task_priority: std_logic_vector(1 downto 0);
    
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
            -- Viene attivato quando i_rst='1' in modo asincrono. 
            -- Scrive 0 all'indirizzo 0 della RAM (azzera il contatore) e 
            -- porta o_done='1' per segnalare che il modulo non è ancora pronto. 
            -- Al ciclo successivo va in IDLE. 
            when RESET => 
            -- non serve l'if di o_done 0 '1' in quanto sei tu stessa che lo stai assegnando, non è una condizione esterna su cui ragionare.
            -- o_done tornerà a '0' automaticamente grazie al default che hai scritto all'inizio del process 
                o_mem_en <= '1';
                o_mem_we <= '1';
                o_mem_addr <= (others => '0');
                o_mem_data <= (others => '0');
                o_done <= '1';
                next_state <= IDLE;
            -- Stato di attesa 
            -- Non fa nulla finché i_start non sale a 1. 
            -- Quando arriva il segnale, salva l'operazione richiesta in next_op (perché i_op potrebbe cambiare durante l'esecuzione) e 
            -- passa a leggere il contatore.
            when IDLE =>
                if i_start = '1' then
                    --o_done <= '0'; per dafault è zero non serve
                    next_state <= READ_COUNT;
                    next_op  <= i_op;
                end if;
            -- Abilita la lettura della RAM all'indirizzo 0 (il default è già addr=0). 
            -- Per OP=11 non serve sapere quanti task ci sono - va direttamente a OP_11. 
            -- Per tutte le altre operazioni va in WAIT_COUNT ad aspettare il dato.
            when READ_COUNT =>
                o_mem_en <= '1';
                o_mem_we <= '0';
                -- o_done <= '1'; a fine operazione i_done = 1
                -- leggo cosa c'è nell'indirizzo 0 del task
                -- o_mem_addr <= (others => '0'); non serve perchè ci pensa il deafult
                -- o_mem_data <= (others => '0');
                if(r_op = "11") then
                    next_state <= OP_11;
                elsif (r_op = "01" or r_op = "00" or r_op = "10") then
                    next_state <= WAIT_COUNT;
                end if;
            -- Qui i_mem_data contiene finalmente il valore di addr=0 (il contatore). Lo salva in next_count. 
            -- Poi fa il branch in base all'operazione, gestendo anche il caso lista vuota per OP_00, OP_01 e OP_10.
            when WAIT_COUNT =>            
                --- r_task_count usa il vecchio valore
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
            -- Scrive 0 all'indirizzo 0, azzerando il contatore. 
            -- Il contenuto degli altri indirizzi rimane invariato ma viene ignorato. 
            -- Un solo ciclo e va in DONE.
            when OP_11 =>
                o_mem_en <= '1';
                o_mem_we <= '1';
                o_mem_addr <= (others => '0');
                o_mem_data <= (others => '0');
                --il contenuto degli altri indirizzi può essere ignorato (quello che è stato scritto in passato riamane invariato) 
                --o resettato (tutti i valori sono posti a zero).
                next_state <= DONE;
            -- Scorre tutti i task da addr=1 fino a r_task_count. 
            -- Per ogni task: READ manda l'indirizzo, 
            -- WRITE legge i_mem_data (arrivato un ciclo dopo) e riscrive incrementando i 2 bit di priorità. 
            -- La saturazione a "11" è gestita con l'if. 
            -- L'indice parte da 1 in WAIT_COUNT e termina quando r_index >= r_task_count.
            when OP_00_READ =>
                 o_mem_en   <= '1';
                 o_mem_we   <= '0'; -- ? solo lettura
                 o_mem_addr <= std_logic_vector(to_unsigned(r_index, 16));
                 next_state <= OP_00_WRITE;
            when OP_00_WRITE =>
                  o_mem_en   <= '1';
                  o_mem_we   <= '1';
                  o_mem_addr <= std_logic_vector(to_unsigned(r_index, 16));
                  if i_mem_data(1 downto 0) = "11" then -- ? i_mem_data valido
                       o_mem_data <= i_mem_data(7 downto 2) & "11";
                  else
                       o_mem_data <= i_mem_data(7 downto 2) & std_logic_vector(unsigned(i_mem_data(1 downto 0)) + 1);
                  end if;
                  if r_index >= r_task_count then -- ? fix #5: >= corretto
                       next_state <= DONE;
                  else
                       next_index <= r_index + 1;
                       next_state <= OP_00_READ;
                  end if;
            -- Il primo ciclo con r_index=1 serve solo a mandare addr=1 alla RAM e impostare r_index=2. 
            -- Non va in WRITE perché il dato non è ancora disponibile.
            -- Il secondo ciclo con r_index=2 ha finalmente i_mem_data = contenuto di addr=1 
            -- — lo salva in r_first e poi va in WRITE.
            when OP_01_READ =>
                  o_mem_en   <= '1';
                  o_mem_we   <= '0'; 
                  o_mem_addr <= std_logic_vector(to_unsigned(r_index, 16));
                  if r_index = 1 then 
                       next_index <= 2;
                       next_state <= OP_01_READ; -- ciclo extra per leggere addr=1; --next_first <= i_mem_data(7 downto 2); -- i_mem_data = addr 1
                  else
                      if r_index = 2 then
                         next_first <= i_mem_data(7 downto 2);  -- addr=1 arriva qui
                      end if;
                         next_state <= OP_01_WRITE;
                  end if;
            -- Scrive il contenuto di addr=r_index in addr=r_index-1, 
            -- shiftando tutti i task di una posizione verso sinistra. 
            -- Termina quando r_index = r_task_count + 1 (uno in più rispetto al vecchio limite perché ora l'indice parte da 2 invece di 2 direttamente).
            when OP_01_WRITE =>
                   o_mem_en   <= '1';
                   o_mem_we   <= '1';
                   o_mem_addr <= std_logic_vector(to_unsigned(r_index - 1, 16));
                   o_mem_data <= i_mem_data; -- ? valido: letto in OP_01_READ
                   --if r_index = 2 then -- ? fix #4: timing corretto
                       --next_first <= i_mem_data(7 downto 2); -- i_mem_data = addr 1
                   --end if;
                   if r_index = r_task_count +1  then
                       next_state <= UPDATE_COUNT;
                   else
                       next_index <= r_index + 1;
                       next_state <= OP_01_READ;
                   end if;
            -- Emette su o_task_id l'ID del primo task rimosso (salvato in r_first), oppure 0 se la lista era vuota. 
            -- Porta o_done='1'.
            when OP_01_OUT =>
                if(r_task_count = 0) then 
                    o_task_id <= (others => '0');
                else 
                    o_task_id <= r_first;
                end if;
                o_done <= '1';
                next_state <= DONE;
            -- Scorre la lista cercando la posizione di inserimento. 
            -- Se r_index > r_task_count ha superato tutti i task — inserisce in fondo. 
            -- Altrimenti passa a leggere il task corrente per confrontare la priorità.
            when OP_10 =>
                --- non li posso già togliere in quanto per default ha questi valori
                o_mem_en <= '1';
                o_mem_we <= '0';
                o_mem_addr <= std_logic_vector(to_unsigned(r_index, 16));
                if (r_index > r_task_count) then
                    next_insert_pos <= r_task_count + 1; 
                    next_state <= OP_10_INSERT;  -- trovato fine lista
                else
                    next_state <= OP_10_SHIFT_READ; --sposto il confronto a shift read, così passa un ciclo per leggere i_mem_data
                end if;
            -- Ha due ruoli: se r_insert_pos > 0 la posizione è già trovata e sta facendo lo shift — va direttamente a WRITE. 
            -- Altrimenti confronta la priorità del task letto con quella del nuovo task. 
            -- Se il task esistente ha priorità numericamente maggiore (= gerarchicamente inferiore), 
            -- ha trovato la posizione di inserimento, salva r_index come r_insert_pos e porta r_index all'ultimo task per iniziare lo shift da destra. 
            -- Altrimenti continua a cercare.
            when OP_10_SHIFT_READ =>
                 o_mem_en   <= '1';
                 o_mem_we   <= '0'; -- ? solo lettura
                 o_mem_addr <= std_logic_vector(to_unsigned(r_index, 16));
                 if(r_insert_pos > 0) then
                 -- r_insert_pos già trovato, stai shiftando
                    next_state <= OP_10_SHIFT_WRITE;   
                 elsif (unsigned(i_mem_data(1 downto 0)) > unsigned(i_task_priority)) then
                 --In VHDL il confronto > su std_logic_vector non è definito dallo standard senza cast — funziona in simulazione con alcune librerie ma può dare problemi in sintesi. 
                    --ho trovato la posizione, posso shiftare
                    next_insert_pos <= r_index; 
                    next_index <= r_task_count; 
                    next_state <= OP_10_SHIFT_READ; 
                 else    
                    --continuo a cercare 
                    next_index <= r_index + 1; 
                    next_state <= OP_10; 
                 end if;       
            -- Sposta ogni task una posizione avanti (da destra verso sinistra). 
            -- Scrive il dato letto nel ciclo precedente in r_index + 1. 
            -- Quando arriva alla posizione di inserimento, va a OP_10_INSERT.     
            when OP_10_SHIFT_WRITE =>
                 o_mem_en   <= '1';
                 o_mem_we   <= '1';
                 o_mem_addr <= std_logic_vector(to_unsigned(r_index + 1, 16));
                 o_mem_data <= i_mem_data; -- ? valido: letto nel ciclo precedente
                 if r_index = r_insert_pos then
                     next_state <= OP_10_INSERT;
                 else
                     next_index <= r_index - 1;
                     next_state <= OP_10_SHIFT_READ;
                 end if;
            -- Scrive il nuovo task nella posizione trovata, 
            -- combinando i_task_id e i_task_priority in un unico byte.
            when OP_10_INSERT =>
                o_mem_en   <= '1';
                o_mem_we   <= '1';
                o_mem_addr <= std_logic_vector(to_unsigned(r_insert_pos, 16));
                o_mem_data <= i_task_id & i_task_priority;
                next_state <= UPDATE_COUNT;
            --- POSSO ANCHE NON FARLO
            -- Aggiorna il contatore all'indirizzo 0. 
            -- Per OP_10 incrementa e va in DONE. 
            -- Per OP_01 decrementa e va in OP_01_OUT per emettere l'ID del task rimosso.
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
        -- o_done='1' in OP_01_OUT — è ridondante?
--Tecnicamente non è ridondante per una ragione sottile: OP_01_OUT deve emettere o_task_id valido contemporaneamente a o_done='1', come richiesto dalla specifica. 
-- Lo stato DONE non emette o_task_id — lo lascia al valore di default 000000. 
-- Quindi se togliessi o_done='1' da OP_01_OUT e lo lasciassi solo in DONE, ci sarebbe un ciclo in cui o_done è ancora 0 mentre sei in OP_01_OUT con o_task_id valido 
-- — il testbench controlla o_task_id sul fronte di o_done='1', quindi deve essere tutto contemporaneo. 
-- Lasciarlo in OP_01_OUT è corretto.

            
        
                    
                    
