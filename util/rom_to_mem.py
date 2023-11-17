import sys

digits = [
    'F0', '90', '90', '90', 'F0', # 0
    '20', '60', '20', '20', '70', # 1
    'F0', '10', 'F0', '80', 'F0', # 2
    'F0', '10', 'F0', '10', 'F0', # 3
    '90', '90', 'F0', '10', '10', # 4
    'F0', '80', 'F0', '10', 'F0', # 5
    'F0', '80', 'F0', '90', 'F0', # 6
    'F0', '10', '20', '40', '40', # 7
    'F0', '90', 'F0', '90', 'F0', # 8
    'F0', '90', 'F0', '10', 'F0', # 9
    'F0', '90', 'F0', '90', '90', # A
    'E0', '90', 'E0', '90', 'E0', # B
    'F0', '80', '80', '80', 'F0', # C
    'E0', '90', '90', '90', 'E0', # D
    'F0', '80', 'F0', '80', 'F0', # E
    'F0', '80', 'F0', '80', '80', # F
]

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('not enough arguments (input file, output file)')
    else:
        rom = b''
        with open(sys.argv[1], 'rb') as f:
            rom = f.read()
        byte_list = [b.to_bytes(1, sys.byteorder).hex() for b in rom]
        # pad with 80 byte of digits data and (0x200 - 80) zeroes
        byte_list = digits + ['00' for _ in range(0x200 - 80)] + byte_list
        # pad to 0x1000 total length
        byte_list.extend('00' for _ in range(0x1000 - len(byte_list) + 0x100 + 18))
        # pc
        byte_list.extend(('02', '00'))
        byte_list.extend('00' for _ in range(4407 - len(byte_list)))
        with open(sys.argv[2], 'w') as f:
            f.write('\n'.join(byte_list))
