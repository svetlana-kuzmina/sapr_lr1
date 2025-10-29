module apb_slave(
	//входы — это сигналы от мастера, 
	//выходы — сигнализируют результат

	input pclk, 		//синхросигнал - тактовый сигнал для синхронизации
	input presetn, 		// инверсный сигнал сброса (0 — сброс, 1 — работа)
	input [31:0] paddr, //адрес обращения - куда мастер хочет записать/прочитать
	input [31:0] pwdata,//данные для записи в slave
	input psel, 		// признак выбора устройсва (1 — master обращается)
	input penable, 		//признак активной транзакции
	input pwrite, 		// признак операции записи 1 — запись, 0 — чтение

	output logic pready, 		// признак готовности от устройства: 1 — slave готов обработать операцию
	output logic pslverr, 		// опционально: признак ошибки при обращении: 1 — ошибка доступа (например, неверный адрес)
	output logic [31:0] prdata 	// прочитанные данные - возвращаемые slave при чтении
);
	// внутренний регистр для хранения данных
	logic [31:0] register_with_some_name;

	// отдельные регистры для каждого адреса
    logic [31:0] reg_number;    // 0x0
    logic [31:0] reg_date;      // 0x4
    logic [31:0] reg_surname;   // 0x8
    logic [31:0] reg_name;      // 0xC

	// FSM (Finite State Machine) — конечный автомат ("мозг" слейва) - решает, что делать в каждый момент
	// APB_SETUP — подготовка к транзакции
	// APB_W_ENABLE — фаза записи
	// APB_R_ENABLE — фаза чтения
	enum logic [1:0] {APB_SETUP, APB_W_ENABLE, APB_R_ENABLE} apb_st;

	//always @(posedge pclk) — блок выполняется на каждый фронт тактового сигнала.
	// Если presetn = 0 (сброс), то:
	// Очищаем данные (prdata = 0)
	// Нет ошибки (pslverr = 0)
	// Слейв не готов (pready = 0)
	// Регистр очищен (register_with_some_name = 0)
	// FSM переходит в состояние APB_SETUP
	// (инициализация всех сигналов при старте)
	always @(posedge pclk)
		if (!presetn) begin
			prdata <= '0;
			pslverr <= 1'b0;
			pready <= 1'b0;
			// register_with_some_name <= 32'h0;
			reg_number  <= 32'h0;
            reg_date    <= 32'h0;
            reg_surname <= 32'h0;
            reg_name    <= 32'h0;
			apb_st <= APB_SETUP;
		end 
		else begin
			case(apb_st)

				APB_SETUP: // ждём, пока мастер выберет слейв (psel=1) и не включена активная фаза (penable=0).
				begin: apb_setup_st
						// clear the prdata and error
						prdata <= '0;
						pready <= 1'b0;
						
						if (psel && !penable) begin // Move to ENABLE when the psel is asserted
							if (pwrite == 1'b1) begin // Если pwrite=1, переключаемся на запись, иначе на чтение
								apb_st <= APB_W_ENABLE; // мастер хочет записать
								end 
							else begin 
								apb_st <= APB_R_ENABLE; // мастер хочет прочитать
								end
						end
				end: apb_setup_st

				APB_W_ENABLE: //пишем данные в регистр
				// pready=1 — мастер знает, что данные приняты
				// case (paddr[7:0]) — выбираем, какой регистр записывать по адресу
				// default — если адрес невалидный, ставим pslverr=1
				begin: apb_w_en_st
					if (psel && penable && pwrite) begin
						pready <= 1'b1; // сигнализируем мастеру, что готовы принять данные

						case (paddr[7:0])
							8'h0: begin reg_number  <= pwdata; $display("Write number to 0x0: %h", pwdata); end
                            8'h4: begin reg_date    <= pwdata; $display("Write date to 0x4: %h", pwdata); end
                            8'h8: begin reg_surname <= pwdata; $display("Write surname to 0x8: %h", pwdata); end
                            8'hC: begin reg_name    <= pwdata; $display("Write name to 0xC: %h", pwdata); end
							default: begin pslverr <= 1'b1; end // ошибка, адрес не существует
						endcase

						apb_st <= APB_SETUP; // возвращаемся в состояние ожидания
					end
				end: apb_w_en_st

				APB_R_ENABLE: // чтение данных
				// prdata получает значение из регистра
				// pready=1 сообщает мастеру, что можно считывать данные
				begin: apb_r_en_st
					if (psel && penable && !pwrite) begin
						pready <= 1'b1; // сигнал готовности

						case (paddr[7:0])
							8'h0: prdata <= reg_number;
                            8'h4: prdata <= reg_date;
                            8'h8: prdata <= reg_surname;
                            8'hC: prdata <= reg_name;
							default: begin pslverr <= 1'b1; end // ошибка, если адрес не существует
						endcase

						apb_st <= APB_SETUP; // возвращаемся в состояние ожидания
					end
				end: apb_r_en_st

				default: begin pslverr <= 1'b1; end //Если FSM в неизвестном состоянии — сигнал ошибки
			endcase

		end // закончился блок внутри always

endmodule