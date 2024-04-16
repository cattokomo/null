return require("init") {
    name = "uwu",
    version = "0.1.0",
    dependencies = {
        hello = {
            url = "http://localhost:8000/hello.tar.gz",
            hash = "80bb530d16e7e175254af6f675502abe64617e1bc6e8b13901f4f18fbed768b1"
        }
    },
    add_path = {
        "./src"
    }
}
