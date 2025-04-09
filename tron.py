from tronpy import Tron

# Initialize the Tron client
tron = Tron()

# Convert Tron address to hexadecimal format
tron_address = "your tron address"
hex_address = tron.address.to_hex(tron_address)
print(f"Hexadecimal Address: {hex_address}")
