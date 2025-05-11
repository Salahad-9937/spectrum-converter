import os
import struct
import glob
import re

def find_metadata_positions(data):
    positions = {}
    known_strings = {
        "InstType": b"LS55",
        "InstID": b"79406",
        "Version": b"F1",
        "Method": b"Scan",
        "Lamp": b"ON",
        "Technique": b"FL"
    }

    for key, signature in known_strings.items():
        pos = data.find(signature)
        if pos != -1:
            positions[key] = pos

    # Поиск даты
    date_pattern = r"[A-Za-z]{3} [A-Za-z]{3} \d{1,2} \d{2}:\d{2}:\d{2} \d{4}|\d{1,2}/\d{1,2}/\d{4} \d{1,2}:\d{2}:\d{2} [AP]M"
    i = 0
    while i < len(data):
        chunk = data[i:min(i+50, len(data))].decode('ascii', errors='ignore')
        match = re.search(date_pattern, chunk)
        if match:
            positions["CreationDate"] = i + match.start()
            break
        i += 1

    # Поиск имени файла (кириллица)
    name_pattern = b"\x23\x30\x31\x2E\x73\x70"  # "#01.sp"
    pos = data.find(name_pattern)
    if pos != -1:
        i = pos - 1
        while i > 0 and data[i] != 0x22:  # Ищем кавычку "
            i -= 1
        if data[i] == 0x22:
            positions["FileName"] = i + 1

    return positions

def find_spectral_data_start(data, metadata):
    if not (metadata["Abscissa Start"] and metadata["Abscissa End"] and metadata["Abscissa Interval"]):
        return len(data)

    # Вычисляем количество точек и размер данных
    num_points = int((metadata["Abscissa End"] - metadata["Abscissa Start"]) / metadata["Abscissa Interval"] + 1)
    data_size = num_points * 8  # 8 байт на double

    # Начинаем с конца файла
    start_pos = len(data) - data_size
    if start_pos < 0:
        start_pos = 0

    return start_pos

def parse_metadata(file_path):
    metadata = {
        "CreatedBy": "",
        "CreationDate": "",
        "SampleID": "",
        "SampleInfo": "",
        "Technique": "",
        "InstType": "",
        "InstID": "",
        "Version": "",
        "Fixed Wavelength [nm]": "",
        "Emission Slit Width [nm]": "",
        "Excitation Slit Width [nm]": "",
        "Method": "",
        "Flash Rate": "",
        "Cycle Time [ms]": "",
        "Gate Time [ms]": "",
        "Delay Time [ms]": "",
        "Scan Speed [nm/min]": "",
        "Instrument Mode": "Fluorescence",
        "Monochromator": "Emission",
        "Monochromator Qualifier": "CW",
        "Filter Position": "",
        "Filter Wheel": "Fitted",
        "Lamp": "",
        "TD Emission Wavelength": "",
        "TD Excitation Wavelength": "",
        "Polarizers": "Fitted",
        "Emission Polarizer": "clear",
        "Excitation Polarizer": "clear(auto cutoff on)",
        "Abscissa Start": 0.0,
        "Abscissa End": 0.0,
        "Abscissa Interval": 0.0,
        "Ordinate Min": 0.0,
        "Ordinate Max": 0.0
    }

    spectral_data = []

    with open(file_path, 'rb') as f:
        data = f.read()

    positions = find_metadata_positions(data)

    # Извлечение строк
    for key, pos in positions.items():
        if key == "InstType" and pos + 4 <= len(data):
            metadata["InstType"] = data[pos:pos+4].decode('ascii')
        elif key == "InstID" and pos + 5 <= len(data):
            metadata["InstID"] = data[pos:pos+5].decode('ascii')
        elif key == "Version" and pos + 2 <= len(data):
            metadata["Version"] = data[pos:pos+2].decode('ascii')
        elif key == "Method" and pos + 4 <= len(data):
            metadata["Method"] = data[pos:pos+4].decode('ascii')
        elif key == "Lamp" and pos + 2 <= len(data):
            metadata["Lamp"] = data[pos:pos+2].decode('ascii')
        elif key == "Technique" and pos + 2 <= len(data):
            metadata["Technique"] = data[pos:pos+2].decode('ascii')
        elif key == "CreationDate" and pos + 50 <= len(data):
            date_str = data[pos:pos+50].decode('ascii', errors='ignore')
            match = re.search(r"[A-Za-z]{3} [A-Za-z]{3} \d{1,2} \d{2}:\d{2}:\d{2} \d{4}|\d{1,2}/\d{1,2}/\d{4} \d{1,2}:\d{2}:\d{2} [AP]M", date_str)
            if match:
                date_str = match.group(0)
                if "/" in date_str:
                    parts = date_str.split()
                    month, day, year = parts[0].split("/")
                    time, period = parts[1].split(" ")
                    formatted_date = f"{day}.{month}.{year} {time} {period}"
                else:
                    parts = date_str.split()
                    month_map = {"Jan": "01", "Feb": "02", "Mar": "03", "Apr": "04", "May": "05", "Jun": "06", "Jul": "07", "Aug": "08", "Sep": "09", "Oct": "10", "Nov": "11", "Dec": "12"}
                    day, month, time, year = parts[2], parts[1], parts[3], parts[4]
                    formatted_date = f"{day}.{month_map.get(month, '01')}.{year} {time}"
                metadata["CreationDate"] = formatted_date
        elif key == "FileName" and pos + 50 <= len(data):
            end_pos = data.find(b"\x22", pos)
            if end_pos != -1:
                file_name = data[pos:end_pos].decode('cp1251', errors='ignore')
                metadata["SampleID"] = file_name.split('#')[0]

    # Извлечение числовых значений (относительно InstType)
    if "InstType" in positions:
        base_pos = positions["InstType"]
        number_positions = [
            ("Fixed Wavelength [nm]", base_pos + 49, '<d', lambda x: f"{x:.1f}", 8),
            ("Emission Slit Width [nm]", base_pos + 69, '<d', lambda x: f"{x:.1f}".replace('.', ','), 8),
            ("Excitation Slit Width [nm]", base_pos + 89, '<d', lambda x: f"{x:.1f}".replace('.', ','), 8),
            ("Flash Rate", base_pos + 123, '<H', lambda x: f"{x:.0f}", 2),
            ("Cycle Time [ms]:", base_pos + 137, '<I', lambda x: f"{x:.0f}", 4),
            ("Gate Time [ms]", base_pos + 127, '<H', lambda x: f"{x/1:.2f}".replace('.', ','), 2),
            ("Delay Time [ms]", base_pos + 131, '<H', lambda x: f"{x/1:.2f}".replace('.', ','), 2),
            ("Scan Speed [nm/min]", base_pos + 199, '<H', lambda x: f"{x:.0f}", 2),
            ("TD Emission Wavelength", base_pos + 295, '<H', lambda x: f"{x:.0f}", 2),
            ("TD Excitation Wavelength", base_pos + 311, '<H', lambda x: f"{x:.0f}", 2),
            ("Filter Position", base_pos + 269, '<H', lambda x: f"{x:.0f}", 2),
            ("Abscissa Start", base_pos + 467, '<d', lambda x: x, 8),
            ("Abscissa End", base_pos + 475, '<d', lambda x: x, 8),
            ("Ordinate Min", base_pos + 491, '<d', lambda x: x, 8),
            ("Ordinate Max", base_pos + 499, '<d', lambda x: x, 8),
            ("Abscissa Interval", base_pos + 515, '<d', lambda x: x, 8)
        ]

        for key, pos, fmt, format_func, size in number_positions:
            try:
                if len(data) >= pos + size:
                    value = struct.unpack(fmt, data[pos:pos+size])[0]
                    metadata[key] = format_func(value)
            except struct.error:
                pass

    # Находим начало спектральных данных с конца файла
    start_pos = find_spectral_data_start(data, metadata)

    # Парсинг спектральных данных
    if metadata["Abscissa Start"] and metadata["Abscissa End"] and metadata["Abscissa Interval"]:
        num_points = int((metadata["Abscissa End"] - metadata["Abscissa Start"]) / metadata["Abscissa Interval"] + 1)
        wavelength = metadata["Abscissa Start"]
        step = 8  # double = 8 байт

        for i in range(start_pos, start_pos + num_points * step, step):
            try:
                intensity = struct.unpack('<d', data[i:i+step])[0]
                if 0 <= intensity < 1e6:  # Фильтр для исключения мусора
                    spectral_data.append((wavelength, intensity))
                wavelength += metadata["Abscissa Interval"]
            except struct.error:
                break

    return metadata, spectral_data, positions

def save_metadata(metadata, spectral_data, output_file):
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("BL ASCII\n")
        f.write("#Hdr\n")
        for key, value in metadata.items():
            if key not in ["Abscissa Start", "Abscissa End", "Abscissa Interval", "Ordinate Min", "Ordinate Max"]:
                f.write(f"{key}:\t{value}\n")
        f.write("#Data\n")
        f.write("WL[nm]\t_[#]\t\n")
        for wavelength, intensity in spectral_data:
            wl_str = f"{wavelength:.1f}".replace('.', ',')
            int_str = f"{intensity:.4f}".replace('.', ',')
            f.write(f"{wl_str}\t{int_str}\t\n")

def save_metadata_details(metadata, positions, output_file):
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("Metadata Details with Addresses\n")
        f.write("Key\tValue\tAddress\n")
        for key, value in metadata.items():
            addr = positions.get(key, "N/A")
            f.write(f"{key}\t{value}\t{addr}\n")

def extract_sp_metadata():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    for sp_file in glob.glob(os.path.join(current_dir, "*.sp")):
        output_file = os.path.splitext(sp_file)[0] + "_metadata.txt"
        detail_file = os.path.splitext(sp_file)[0] + "_metadata_details.txt"
        metadata, spectral_data, positions = parse_metadata(sp_file)
        save_metadata(metadata, spectral_data, output_file)
        save_metadata_details(metadata, positions, detail_file)
        print(f"Метаданные и спектр сохранены в {output_file}")
        print(f"Детали метаданных сохранены в {detail_file}")

if __name__ == "__main__":
    extract_sp_metadata()