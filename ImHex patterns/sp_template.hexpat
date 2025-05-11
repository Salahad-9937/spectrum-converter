// Шаблон для парсинга метаданных файлов .sp в ImHex

#include <std/mem.pat>
#include <std/string.pat>
#include <std/io.pat>

// Настройки препроцессора
#pragma endian little
#pragma magic [ 50 45 50 45 32 44 ] @ 0x00 // "PEPE2D" в начале файла
#pragma base_address 0x00

// Функция для поиска адреса Instrument Type
fn find_metadata_start() {
    // Ищем сигнатуру "LS55" в диапазоне 0x100-0x300
    u128 inst_type_pos = std::mem::find_string_in_range(0, 0x100, 0x300, "LS55");
    return inst_type_pos;
};

// Пространство имен для организации кода
namespace sp {

    // Структура для метаданных
    struct Metadata {
        // Текстовые заголовки (фиксированные адреса, так как работали)
        char header[0x25] @ 0x00 [[name("File Header")]];
        char smootht[0x07] @ 0x5D [[name("Smootht Text")]];
        char creation_date[0x19] @ 0x6D [[name("Creation Date")]];
        //! Нужно доработать поиск имён файлов
        //char user_file_name[0x5C] @ 0x87 [[name("First User's File Name")]];
        //char user_file_name2[0x5C] @ 0x87 [[name("Second User's File Name")]];
        
        // Метаданные () //! В дальнейшем использовать как сигнатуры
        char last_modified[0x25] @ (find_metadata_start() - 0xEF) [[name("Last Modified Record2")]];
        char perkin_elmers[0x0C] @ (find_metadata_start() - 0x87) [[name("PerkinElmers")]];
        char created_as_new[0x17] @ (find_metadata_start() - 0x72) [[name("Created As New DataSet")]];
        char creation_date2[0x19] @ (find_metadata_start() - 0x52) [[name("Second Creation Date")]];
        

        // Параметры инструмента
        char inst_type[0x04] @ find_metadata_start() [[name("Instrument Type")]];
        char inst_id[0x05] @ (find_metadata_start() + 0x0E) [[name("Instrument ID")]];
        char version[0x02] @ (find_metadata_start() + 0x1D) [[name("Version")]];

        double fixed_wavelength @ (find_metadata_start() + 0x31) [[name("Fixed Wavelength [nm]")]];
        double emission_slit_width @ (find_metadata_start() + 0x45) [[name("Emission Slit Width [nm]")]];
        double excitation_slit_width @ (find_metadata_start() + 0x59) [[name("Excitation Slit Width [nm]")]];
        char method[0x04] @ (find_metadata_start() + 0x6F) [[name("Method")]];
        
        s16 flash_rate @ (find_metadata_start() + 0x7B) [[name("Flash Rate")]]; //! Не проверно на достоверность
        s16 cycle_time @ (find_metadata_start() + 0x89) [[name("Cycle Time [ms]")]];
        s16 gate_time @ (find_metadata_start() + 0x7F) [[name("Gate Time [ms]")]]; //! Не проверно на достоверность
        
        s16 delay_time @ (find_metadata_start() + 0x83) [[name("Delay Time [ms]")]]; //! Определяется некорректно
        s16 scan_speed @ (find_metadata_start() + 0xC7) [[name("Scan Speed [nm/min]")]];
        s16 filter_position @ (find_metadata_start() + 0x10D) [[name("Filter Position")]]; //! Не проверно на достоверность
        char lamp[0x02] @ (find_metadata_start() + 0x11D) [[name("Lamp Status")]];
        s16 td_emission_wavelength @ (find_metadata_start() + 0x127) [[name("TD Emission Wavelength [nm]")]];
        s16 td_excitation_wavelength @ (find_metadata_start() + 0x137) [[name("TD Excitation Wavelength [nm]")]];

        // Параметры файла при создании
        char file_path[0x1C] @ (find_metadata_start() + 0x1AF) [[name("File Path")]];
        char technique[0x02] @ (find_metadata_start() + 0x1B2) [[name("Technique")]];
        char file_name[0x08] @ (find_metadata_start() + 0x1C0) [[name("File Name")]];

        // Параметры спектра
        double abscissa_start @ (find_metadata_start() + 0x1D3) [[name("Abscissa Start [nm]")]];
        double abscissa_end @ (find_metadata_start() + 0x1DB) [[name("Abscissa End [nm]")]];
        double ordinate_min @ (find_metadata_start() + 0x1EB) [[name("Ordinate Min")]];
        double ordinate_max @ (find_metadata_start() + 0x1F3) [[name("Ordinate Max")]];
        double abscissa_interval @ (find_metadata_start() + 0x203) [[name("Abscissa Interval [nm]")]];
        
        char sample_id[0x2A] @ (find_metadata_start() + 0x257) [[name("Sample ID")]]; //! Определяется некорректно
    };

    // Основная структура файла
    struct File {
        Metadata metadata @ 0x00 [[name("Metadata")]];
    };

}

// Размещаем основную структуру
sp::File sp_file @ 0x00 [[name("SP File")]];