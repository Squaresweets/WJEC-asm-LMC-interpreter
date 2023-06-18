let input = prompt("Enter the program: ")
console.clear()
let a = input.split(" ")
for (let i in a) {
  let s = parseInt(a[i]).toString(16).padStart(4, "0")
  console.log(`movlw 0x${s.substr(0, 2)}          ;${a[i]}\ncall blit`)
  console.log(`movlw 0x${s.substr(2, 2)}\ncall blit`)
}