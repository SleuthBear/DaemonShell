#+feature dynamic-literals
package saved_locks

Lock_Info :: struct {
        hint, answer: string
}

// TODO extract to a yaml file, and parse. Saves compile time.

// This is implicitly allocated. Doesn't matter in this case, but good to know!
locks := map[string]Lock_Info{
        "Backup_755012715.lock" = {"brother in law", "Jacob"},
        "Code_163903526.lock" = {"first BDOWDC champion", "Leighton Rees"},
        "Logs_1807696380.lock" = {"my zodiac element + symbol", "metal dragon"},
}
        