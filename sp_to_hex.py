import os

def convert_sp_to_hex(input_file, output_file):
    with open(input_file, 'rb') as f:
        data = f.read()
    
    with open(output_file, 'w') as f:
        for i in range(0, len(data), 16):
            chunk = data[i:i+16]
            hex_line = ' '.join(f'{b:02X}' for b in chunk)
            f.write(hex_line + '\n')

def main():
    for file in os.listdir('.'):
        if file.endswith('.sp'):
            output_file = file + '.hex'
            convert_sp_to_hex(file, output_file)
            print(f'Converted {file} to {output_file}')

if __name__ == '__main__':
    main()