const CID = require("cids")
async function main() {
    const cidHexRaw = new CID("baga6ea4seaqjmyhomwcl7jai5hd5cta27uv37vsmatiz7633jr6p6xucztezenq")
        .toString("base16")
        .substring(1)
    const cidHex = "0x00" + cidHexRaw
    console.log("Hex bytes are:", cidHex)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
