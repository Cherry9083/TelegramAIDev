package test

import stdx.encoding.json.*

main() {
    let apiIdStr = ""
    let parsedApiId = Int64.parse(apiIdStr)

    let obj = JsonObject()
    obj.put("api_id", JsonInt(parsedApiId))
    obj.put("test", JsonInt())

    println("Parsed: ${parsedApiId}")
    println("JSON: ${obj.toString()}")
}
