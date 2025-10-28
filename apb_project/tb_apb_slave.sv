`timescale 1ns/1ps // Определяет единицы времени для симуляции 
// 1ns — шаг времени (1 такт = 1 наносекунда)
// 1ps — точность временных задержек (минимальная единица = 1 пикосекунда)

module TB; //нет входов или выходов, он только проверяет слейв

    // сигналы
    // совпадают с входами и выходами слейва
    // logic — переменные, можно присваивать внутри блока
    // wire — “провод”, который соединяет модуль со слейвом
    logic pclk;
    logic presetn;
    logic psel;
    logic penable;
    logic pwrite;
    logic [31:0] paddr;
    logic [31:0] pwdata;

    wire [31:0] prdata;
    wire pready;
    wire pslverr;

    parameter p_device_offset = 32'h7000_0000; //базовый адрес устройства

    logic [31:0] address; //текущий адрес для записи/чтения
    logic [31:0] data_to_device; //данные, которые мастер хочет записать
    logic [31:0] data_from_device; //данные, которые мастер хочет прочитать

    // подключаем DUT - Device Under Test
    // создаём экземпляр слейва
    // Через .имя_порта(сигнал) связываем сигналы тестбенча и слейва: теперь все действия в тестбенче будут управлять слейвом
    apb_slave DUT (
        .pclk(pclk),        //синхросигнал
        .presetn,           //сигнал сброса
        .paddr(paddr),      //адрес обращения
        .pwdata(pwdata),    //данные для записи
        .psel(psel),        // признак выбора устройсва
        .penable(penable),  //признак активной транзакции
        .pwrite(pwrite),    // признак операции записи
        .pready(pready),    // признак готовности от устройства
        .pslverr(pslverr),  // опционально: признак ошибки при обращении
    .   prdata(prdata)      // прочитанные данные
    );

    // задачи (tasks) для записи/чтения
    // пошагово имитирует запись в слейв
    task apb_write(input [31:0] addr, [31:0] data);

        wait ((penable==0) && (pready == 0)); //Ждём, пока предыдущая транзакция завершится

        @(posedge pclk); //На фронте pclk
        psel <= 1'b1; //выбираем слейв
        paddr[31:0] <= addr[31:0]; //выставляем адрес и данные
        pwdata[31:0] <= data[31:0];
        pwrite <= 1'b1; //Устанавливаем что будет запись

        @(posedge pclk);
        penable <= 1'b1; //Включаем активную фазу

        @(posedge pclk);
        wait (pready == 1'b1); //Ждём, пока слейв ответит

        @(posedge pclk);
        psel <= 1'b0; //Завершаем транзакцию (psel=0, penable=0, pwrite=0)
        penable <= 1'b0;
        pwrite <= 1'b0;
        @(posedge pclk);
    endtask

    task apb_read(input [31:0] addr, output logic [31:0] data);

        wait ((penable==0) && (pready == 0)); //Ждём, пока предыдущая транзакция завершится

        @(posedge pclk);
        psel <= 1'b1; //выбираем слейв
        pwrite <= 1'b0; //pwrite=0 — это чтение
        paddr[31:0] <= addr[31:0]; //выставляем адрес

        @(posedge pclk);
        penable <= 1'b1; //Включаем активную фазу

        @(posedge pclk);
        wait (pready == 1'b1); //Ждём, пока слейв ответит

        @(posedge pclk);
        data[31:0]<=prdata[31:0]; //После завершения активной фазы данные из слейва (prdata) сохраняются в data
        psel <= 1'b0; //Завершаем транзакцию (psel=0, penable=0)
        penable <= 1'b0;
        @(posedge pclk);
    endtask

    // генератор тактового сигнала
    // Меняем pclk каждые 10 нс → получаем период 20 нс, фронт и спад.
    // способ имитировать работу тактового сигнала в симуляции
    always #10 pclk=~pclk;

    // инициализация
    initial begin //блок выполняется один раз в начале симуляции: инициализируем все сигналы и делаем сброс
        pclk=0;
        presetn=1'b1; //Сначала сброс выключен (presetn=1)
        psel='0;
        penable='0;
        pwrite='0;
        paddr='0;
        pwdata='0;
        repeat (5) @(posedge pclk);

        presetn=1'b0; //Потом включаем сброс (presetn=0) на несколько тактов
        repeat (5) @(posedge pclk);

        presetn=1'b1; //Потом выключаем сброс (presetn=1)
        repeat (5) @(posedge pclk);

        // пример записи/чтения - пример работы мастера
        // Пишем данные в регистр слейва
        // Сразу читаем обратно и выводим результат в консоль
        address = p_device_offset+0;
        data_to_device = 32'h12345678;
        apb_write(address, data_to_device);
        apb_read(address, data_from_device);
        $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device, data_from_device);

        data_to_device = 32'h1;
        apb_write(address, data_to_device);
        apb_read(address, data_from_device);
        $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device, data_from_device);

        repeat (10) @(posedge pclk); //Ждём несколько тактов для завершения всех действий
        $stop(); //останавливает симуляцию
        end

    // монитор сигналов
    // $monitor автоматически выводит значения сигналов при любом их изменении
    // Можно отслеживать в консоли, что происходит на шине APB
    initial begin
        $monitor("APB IF state: PENABLE=%b PREADY=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h", penable, pready, paddr, pwdata, prdata);
    end

    // дамп для GTKWave
    // Создаёт файл wave.vcd, который можно открыть в GTKWave
    // Показывает все сигналы тестбенча и слейва на временной диаграмме
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, TB);
    end

endmodule