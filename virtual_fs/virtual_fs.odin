package virtual_fs

import "core:encoding/json"
import "core:os"
import "core:fmt"
import "core:strings"

File_Type :: enum {
        DIRECTORY = 0,
        FILE = 1,
}

Node :: struct {
        name: string,
        type: File_Type,
        parent: ^Node,
        children: [dynamic]^Node,
        file_ref: string
}

read_system :: proc(path: string) -> ^Node {
        data, ok := os.read_entire_file_from_filename(path)
        if !ok {
                fmt.println("Failed to read", path)
                os.exit(1)
        }
        // Remember data must be alloced, since we are working with pointers
        defer delete(data)
        json_data, err := json.parse(data)
        if err != .None {
                fmt.println("Failed to parse", path)
                os.exit(1)
        }
        // TODO figure out how this works without deleting json
        //defer json.destroy_value(json_data)
        root_node := get_node(json_data.(json.Object))
        return root_node
}

// This is basically a tree structure. Now, this is very inefficient, but making it an array is a bit harder,
// and not really necessary. 
get_node :: proc(data: json.Object) -> ^Node {
        if data == nil {
                return nil
        }
        new_node := new(Node)
        new_node.name = data["name"].(json.String)
        new_node.file_ref = data["file_ref"].(json.String)
        new_node.type = File_Type(int(data["type"].(json.Float)))
        if data["children"] != nil {
                for child in data["children"].(json.Array) {
                        child_node := get_node(child.(json.Object))
                        if child_node != nil {
                                child_node.parent = new_node
                                append(&new_node.children, child_node)
                        }
                }
        }
        return new_node;
}

follow_path :: proc(node: ^Node, path: string) -> ^Node {
        node := node
        clean_path, _ := strings.replace_all(path, "\\", "/")
        steps := strings.split(path, "/")
        for step in steps {
                if step == "" {
                        return node
                }
                node = find_child(node, step)
                if node == nil {
                        return nil
                }
                if strings.contains(node.name, ".lock") {
                        return node
                }
        }
        return node
}

find_child :: proc(node: ^Node, name: string) -> ^Node {
        if name == ".." {
                return node.parent
        }
        for child in node.children {
                if child.name == name {
                        return child
                }
        }
        return nil
}