drop table if exists identitas cascade;
create table identitas (
id serial primary key, 
nama varchar(45),
alamat text,
no_telp varchar(15));

drop table if exists anggota cascade;
create table anggota (
status varchar(10),
total_peminjaman int default 0,
primary key(id)) 
inherits (identitas);

drop table if exists pustakawan cascade;
create table pustakawan (
pangkat varchar(45),
primary key(id))
inherits (identitas);

drop table if exists inventaris cascade;
create table inventaris (
id serial primary key,
jumlah int default 0);

drop table if exists buku cascade;
create table buku (
id int primary key, 
no varchar(10) unique, 
judul text, 
stok int, 
jenis varchar(45),
inventaris_id int references inventaris(id));

drop table if exists peminjaman cascade;
create table peminjaman (
id serial primary key, 
tanggal date default now(), 
jumlah int,
anggota_id int references anggota(id),
pustakawan_id int references pustakawan(id),
buku_id int references buku(id));

drop table if exists pengembalian cascade;
create table pengembalian (
id serial primary key, 
tanggal date, 
peminjaman_id int references peminjaman(id),
status varchar(10) default 'Dipinjam');

drop table if exists log cascade;
create table log (
id serial primary key, 
tanggal timestamp default now(),
jumlah int,
inventaris_id int references inventaris(id));

create or replace function
tambah_buku() returns trigger as
$$
	begin
		update inventaris set jumlah = jumlah + new.stok 
		where id = 1;
		return new;
	end
$$ language plpgsql;

create trigger trig_tambah_buku
after insert on buku 
for each row execute procedure tambah_buku();

create or replace function
update_log() returns trigger as
$$
	declare
		j int;
	begin
		if (old.jumlah - new.jumlah) < 1 then
			j = -1 * (old.jumlah - new.jumlah);
		else
			j = -1 * (old.jumlah - new.jumlah);
		end if;
		
		insert into log values
		(default,default,j,old.id);
		return old;
	end
$$ language plpgsql;

create trigger trig_update_log
after update on inventaris
for each row execute procedure update_log();

create or replace function 
minjem() returns trigger as
$$
	begin
		update buku set stok = stok - new.jumlah 
		where id = new.buku_id;
		
		update inventaris set jumlah = jumlah - new.jumlah
		where id = 1;
	
		insert into pengembalian values 
		(default,current_date + integer '7',new.id);				
	
		return new;
	end
$$ language plpgsql;

create trigger trig_minjem
after insert on peminjaman
for each row execute procedure minjem();

create or replace function
update_anggota() returns trigger as
$$
	declare
		p int;
		a int;
	begin		
		select into p peminjaman_id from pengembalian where id = new.peminjaman_id;
		select into a anggota_id from peminjaman where id = p;
		
		update anggota set total_peminjaman = total_peminjaman + 1
		where id = a;
			
		return new;
	end
$$ language plpgsql;

create trigger trig_update_anggota
after insert on pengembalian
for each row execute procedure update_anggota();

create or replace function 
balikin(int) returns void as
$$
	declare
		g alias for $1;
		p int;
		j int;
		b int;				
	begin
		select into p peminjaman_id from pengembalian where id = g; 
		select into j jumlah from peminjaman where id = p;
		select into b buku_id from peminjaman where id = p;
		
		update pengembalian set status = 'Selesai'
		where id = g;
		
		update buku set stok = stok + j 
		where id = b;
	
		update inventaris set jumlah = jumlah + j 
		where id = 1;
	end
$$ language plpgsql;

insert into pustakawan values (default,'Pustakawan A','Alamat A','081234567890','Staff');

insert into anggota values (default,'Anggota B','Alamat B','081234567891','Aktif',default);

insert into inventaris values (1,0);

insert into buku values 
(1,'BK01','Buku A',10,'Jenis A',1),
(2,'BK02','Buku B',20,'Jenis B',1);

insert into peminjaman values 
(default,default,10,2,1,1),
(default,default,17,2,1,2);

select balikin(1);

select * from buku;
select * from inventaris;
select * from log;

select * from peminjaman;
select * from anggota;
select * from pengembalian;

begin transaction;
insert into buku values(3,'BK03','Buku C',2, 'Jenis C',1);
savepoint sp1;

--transaction
insert into peminjaman values(default,default,1,2,1,2);
savepoint sp2;
insert into peminjaman values(default,default,1,2,1,1);
insert into peminjaman values(default,default,1,2,1,1);
insert into peminjaman values(default,default,1,2,1,2);

rollback to sp2;
commit;
select * from peminjaman;
select * from pustakawan;
select balikin(2);

