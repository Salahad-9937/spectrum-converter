// Шаблон для парсинга метаданных файлов .sp в ImHex

#include <std/mem.pat>
#include <std/string.pat>
#include <std/io.pat>

// Настройки препроцессора
#pragma endian little
#pragma magic [ 50 45 50 45 32 44 ] @ 0x00 // "PEPE2D"
#pragma base_address 0x00

// Функция для поиска адреса Instrument Type
fn find_metadata() {
    // Ищем сигнатуру "LS55" в диапазоне 0x100-0x300
    u128 inst_type_pos = std::mem::find_string_in_range(0, 0x100, 0x300, "LS55");
    return inst_type_pos;
};

fn find_sig(str signature) {
    u128 sig = std::mem::find_string_in_range(0, 0x000, 0x5DC, signature);
    return sig;
};

// Поиск первой строки (ufn111, "файл.raw")
fn find_file_name_raw_start() {
    u128 start = find_metadata() - 0x124 - ((find_metadata() - 0x124) - 0x90);
    u128 pos = start;
    while (pos < start + ((find_metadata() - 0x124) - 0x90) + 1) {
        u8 byte = std::mem::read_unsigned(pos, 1);
        if (byte == 34) {
            return pos; // Начало ufn111 (первая 0x22)
        }
        pos = pos + 1;
    }
    std::io::warning("File Name RAW start not found");
    return 0x00;
};

fn find_file_name_raw_end() {
    u128 start = find_metadata() - 0x124 - ((find_metadata() - 0x124) - 0x90);
    u128 pos = start;
    u8 count = 0;
    while (pos < start + ((find_metadata() - 0x124) - 0x90) + 1) {
        u8 byte = std::mem::read_unsigned(pos, 1);
        if (byte == 34) {
            count = count + 1;
            if (count == 2) {
                return pos; // Конец ufn111 (вторая 0x22)
            }
        }
        pos = pos + 1;
    }
    std::io::warning("File Name RAW end not found");
    return 0x00;
};

// Поиск второй строки (ufn222, "файл.sp")
fn find_file_name_sp_start() {
    u128 start = find_metadata() - 0x124 - ((find_metadata() - 0x124) - 0x90);
    u128 pos = start;
    u8 count = 0;
    while (pos < start + ((find_metadata() - 0x124) - 0x90) + 1) {
        u8 byte = std::mem::read_unsigned(pos, 1);
        if (byte == 34) {
            count = count + 1;
            if (count == 3) {
                return pos; // Начало ufn222 (третья 0x22)
            }
        }
        pos = pos + 1;
    }
    std::io::warning("File Name SP start not found");
    return 0x00;
};

fn find_file_name_sp_end() {
    u128 start = find_metadata() - 0x124 - ((find_metadata() - 0x124) - 0x90);
    u128 pos = start;
    u8 count = 0;
    while (pos < start + ((find_metadata() - 0x124) - 0x90) + 1) {
        u8 byte = std::mem::read_unsigned(pos, 1);
        if (byte == 34) {
            count = count + 1;
            if (count == 4) {
                return pos; // Конец ufn222 (четвёртая 0x22)
            }
        }
        pos = pos + 1;
    }
    std::io::warning("File Name SP end not found");
    return 0x00;
};

namespace sp {
    struct Head {       
        char header[0x25] @ 0x00 [[name("File Header")]];
        char smootht[0x07] @ 0x5D [[name("Smootht Text")]];
        char creation_date[0x19] @ 0x6D [[name("Creation Date")]];
    };
    
    struct Signature {
        char last_modified[0x25] @ find_sig("Last Modified Record For New DataSett") [[name("Last Modified Record")]];
        char perkin_elmers[0x0C] @ find_sig("PerkinElmers") [[name("PerkinElmers")]];
        char created_as_new[0x17] @ find_sig("Created As New DataSet") [[name("Created As New DataSet")]];
    };

    struct Metadata {
        // User's file name length - общий блок строк (от первой 0x22 до четвёртой 0x22 включительно)
        // auto ufnl = (find_metadata() - 0x124) - 0x90;
        // char ufn[ufnl + 1] @ (find_metadata() - 0x124 - ufnl) [[name("User's File Name")]];
        
        // Первая строка (ufn111, "файл.raw" с кавычками)
        auto raw_file_len = find_file_name_raw_end() - find_file_name_raw_start() + 1;
        
        
        // Вторая строка (sp_file_name, "файл.sp" с кавычками)
        auto sp_file_len = find_file_name_sp_end() - find_file_name_sp_start() + 1;
        char raw_file_name[raw_file_len] @ find_file_name_raw_start() [[name("RAW File Name")]];
        char sp_file_name[sp_file_len] @ find_file_name_sp_start() [[name("SP File Name")]];
        
        char creation_date2[0x19] @ (find_metadata() - 0x52) [[name("Second Creation Date")]];
        
        // Параметры инструмента
        char inst_type[0x04] @ find_metadata() [[name("Instrument Type")]];
        char inst_id[0x05] @ (find_metadata() + 0x0E) [[name("Instrument ID")]];
        char version[0x02] @ (find_metadata() + 0x1D) [[name("Version")]];

        double fixed_wavelength @ (find_metadata() + 0x31) [[name("Fixed Wavelength [nm]")]];
        double emission_slit_width @ (find_metadata() + 0x45) [[name("Emission Slit Width [nm]")]];
        double excitation_slit_width @ (find_metadata() + 0x59) [[name("Excitation Slit Width [nm]")]];
        char method[0x04] @ (find_metadata() + 0x6F) [[name("Method")]];
        
        s16 flash_rate @ (find_metadata() + 0x7B) [[name("Flash Rate")]]; //! Не проверно на достоверность
        s16 cycle_time @ (find_metadata() + 0x89) [[name("Cycle Time [ms]")]];
        s16 gate_time @ (find_metadata() + 0x7F) [[name("Gate Time [ms]")]]; //! Не проверно на достоверность
        
        s16 delay_time @ (find_metadata() + 0x83) [[name("Delay Time [ms]")]]; //! Определяется некорректно
        s16 scan_speed @ (find_metadata() + 0xC7) [[name("Scan Speed [nm/min]")]];
        s16 filter_position @ (find_metadata() + 0x10D) [[name("Filter Position")]]; //! Не проверно на достоверность
        char lamp[0x02] @ (find_metadata() + 0x11D) [[name("Lamp Status")]];
        s16 td_emission_wavelength @ (find_metadata() + 0x127) [[name("TD Emission Wavelength [nm]")]];
        s16 td_excitation_wavelength @ (find_metadata() + 0x137) [[name("TD Excitation Wavelength [nm]")]];

        // Параметры файла при создании
        char file_path[0x1C] @ (find_metadata() + 0x1AF) [[name("File Path")]];
        char technique[0x02] @ (find_metadata() + 0x1B2) [[name("Technique")]];
        char file_name[0x08] @ (find_metadata() + 0x1C0) [[name("File Name")]];

        // Параметры спектра
        double abscissa_start @ (find_metadata() + 0x1D3) [[name("Abscissa Start [nm]")]];
        double abscissa_end @ (find_metadata() + 0x1DB) [[name("Abscissa End [nm]")]];
        double ordinate_min @ (find_metadata() + 0x1EB) [[name("Ordinate Min")]];
        double ordinate_max @ (find_metadata() + 0x1F3) [[name("Ordinate Max")]];
        double abscissa_interval @ (find_metadata() + 0x203) [[name("Abscissa Interval [nm]")]];
        
        char sample_id[0x21] @ (find_metadata() + 0x25F) [[name("Sample ID")]]; //! Определяется некорректно
    };

    // Основная структура файла
    struct File {
        Head head @ 0x00 [[name("Head")]];
        Signature signature @ 0x00 [[name("Signature")]];
        Metadata metadata @ 0x00 [[name("Metadata")]];
    };

}

// Размещаем основную структуру
sp::File sp_file @ 0x00 [[name("SP File")]];