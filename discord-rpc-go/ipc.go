package main

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"net"
	"os"
)

func connectDiscord() (net.Conn, error) {
	// macOS: $TMPDIR, Linux: /tmp
	tmpDir := os.Getenv("TMPDIR")
	if tmpDir == "" {
		tmpDir = "/tmp"
	}
	for i := 0; i < 10; i++ {
		path := fmt.Sprintf("%sdiscord-ipc-%d", tmpDir, i)
		conn, err := net.Dial("unix", path)
		if err == nil {
			return conn, nil
		}
	}
	return nil, fmt.Errorf("discord IPC socket not found (is Discord running?)")
}

func writeFrame(conn net.Conn, opcode uint32, payload any) error {
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	header := make([]byte, 8)
	binary.LittleEndian.PutUint32(header[0:4], opcode)
	binary.LittleEndian.PutUint32(header[4:8], uint32(len(data)))
	if _, err := conn.Write(header); err != nil {
		return err
	}
	_, err = conn.Write(data)
	return err
}

func readFrame(conn net.Conn) (opcode uint32, data []byte, err error) {
	header := make([]byte, 8)
	if _, err = readFull(conn, header); err != nil {
		return
	}
	opcode = binary.LittleEndian.Uint32(header[0:4])
	length := binary.LittleEndian.Uint32(header[4:8])
	data = make([]byte, length)
	_, err = readFull(conn, data)
	return
}

func readFull(conn net.Conn, buf []byte) (int, error) {
	total := 0
	for total < len(buf) {
		n, err := conn.Read(buf[total:])
		total += n
		if err != nil {
			return total, err
		}
	}
	return total, nil
}
