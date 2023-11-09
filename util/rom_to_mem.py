import sys

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('not enough arguments')
    else:
        rom = b''
        with open(sys.argv[1], 'rb') as f:
            rom = f.read()
        byte_list = [b.to_bytes(1, sys.byteorder).hex() for b in rom]
        # pad with 0x200 zeroes
        byte_list = ['00' for _ in range(0x200)] + byte_list
        # pad to 0x1000 total length
        byte_list.extend('00' for _ in range(0x1000 - len(byte_list) + 0x100 + 18))
        # pc
        byte_list.extend(('02', '00'))
        byte_list.extend('00' for _ in range(4407 - len(byte_list)))
        with open(sys.argv[2], 'w') as f:
            f.write('\n'.join(byte_list))
