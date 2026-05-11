package test

import stdx.encoding.json.*

main() {
    let apiIdStr = "34596433"
    let parsedApiId = Int64.parse(apiIdStr)

    let obj = JsonObject()
    obj.put("api_id", JsonInt(parsedApiId))
    obj.put("test", JsonInt(34596433))

    println("Parsed: ${parsedApiId}")
    println("JSON: ${obj.toString()}")
}
