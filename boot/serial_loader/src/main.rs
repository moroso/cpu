/*
Quick-and-dirty client for the first-stage serial bootloader.
Doesn't do anything resembling reasonable error handling, or
verification of the downloaded program.
*/

use serial;
use serial::posix::TTYPort;
use serial::prelude::*;
use std::io::{Read, Write};
use std::io::ErrorKind::TimedOut;
use std::fs::File;

pub fn get_port() -> TTYPort {
    let port = serial::open("/dev/ttyUSB0");
    let mut port = match port {
        Ok(port) => port,
        Err(err) => { println!("Error opening port: {}", err);
                      ::std::process::exit(1); }
    };
    port.reconfigure(&|settings| {
        settings.set_baud_rate(serial::Baud115200)?;
        settings.set_char_size(serial::Bits8);
        settings.set_flow_control(serial::FlowNone);

        Result::Ok(())
    }).unwrap();

    port
}

fn readchar(port: &mut TTYPort) -> u8 {
    let mut buf = [0; 1];
    loop {
        let res = port.read(&mut buf);
        match res {
            Err(e) if e.kind() == TimedOut => {},
            Err(e) => {
                println!("{:?}", e);
            }
            Ok(l) if l > 0 => {
                return buf[0];
            },
            _ => { },
        }
    }
}

fn wait_header(port: &mut TTYPort) {
    // This isn't particularly efficent, but that doesn't
    // particularly matter.

    let mut buf: Vec<u8> = vec!();
    let target = b"MBOOT";

    println!("Waiting for bootloader...");

    loop {
        let c = readchar(port);
        buf.push(c);
        while &target[0..buf.len()] != &buf[..] {
            buf.remove(0);
        }
        if buf == target {
            return;
        }
    }
}

fn load_program(fname: &str) -> Vec<u8> {
    println!("Loading program from {}...", fname);

    let mut file = File::open(fname).unwrap();
    let mut res = Vec::new();

    file.read_to_end(&mut res).unwrap();
    assert!(res.len() % 16 == 0, "Program length must be a multiple of 16 bytes");
    let packets = res.len() / 16;
    println!("Loaded {} bytes ({} packets)", res.len(), packets);

    res
}

fn print_packet(packet: &[u8]) {
    for i in 0..packet.len() {
        print!("{:02x} ", packet[i]);
        if i % 4 == 3 {
            print!(" ");
        }
    }
}

fn send_program(port: &mut TTYPort, prog: &[u8]) {
    let num_packets = prog.len() / 16;
    port.write(&[num_packets as u8]).unwrap();

    let mut remaining_packets = num_packets as u8;
    for i in 0..num_packets {
        remaining_packets -= 1;
        assert_eq!(readchar(port), remaining_packets);

        print!("Writing packet {}: ", i);
        print_packet(&prog[i * 16..(i+1)*16]);
        println!("");
        let res = port.write(&prog[i * 16..(i+1) * 16]).unwrap();
        assert!(res == 16);
    }

    assert_eq!(readchar(port), b'D');
    assert_eq!(readchar(port), b'O');
    assert_eq!(readchar(port), b'N');
    assert_eq!(readchar(port), b'E');
}

fn hexdump_vec(chars: &[u8]) {
    print!("\r");
    let l = chars.len();

    for i in 0..16 {
        let c = *chars.get(i).unwrap_or(&b' ');
        if i % 8 == 0 { print!(" "); }
        print!("{}", if c >= 0x20 && c <= 0x7e { c as char } else { '.' } );
    }
    print!("  ");
    for i in 0..16 {
        if i % 8 == 0 { print!(" "); }
        match chars.get(i) {
            Some(c) => print!("{:02x} ", c),
            _ => {},
        }
    }

    ::std::io::stdout().flush();
}

fn main() -> Result<(), ::std::io::Error> {
    let prog_filename = ::std::env::args().skip(1).next().expect("Specify a program file");
    let prog = load_program(&prog_filename);

    let mut port = get_port();

    wait_header(&mut port);
    println!("Got bootloader ping. Loading program...");
    send_program(&mut port, &prog);
    println!("Done!");

    loop {
        let mut chars = vec!();
        loop {
            let mut buf = [0; 1];
            let res = port.read(&mut buf);
            match res {
                Err(e) if e.kind() == TimedOut => {},
                Err(e) => {
                    panic!("{:?}", e);
                }
                Ok(l) if l > 0 => { chars.push(buf[0]); hexdump_vec(&chars); },
                _ => { },
            }
            if chars.len() == 16 {
                println!();
            }
        }
    }
}
