-- create database once
CREATE DATABASE lake;

-- dry method of the environmental sample
CREATE TABLE Dry_Method(
	id SMALLSERIAL PRIMARY KEY,
    short_name CHAR(10) UNIQUE NOT NULL,
    temperature REAL,
    duration_hours REAL,
    description TEXT NOT NULL
);

-- generic experiment table storing properties common to all sorts of experiments
CREATE TABLE Experiment(
    id SERIAL PRIMARY KEY,
    sample_ids INTEGER[] NOT NULL,
    date TIMESTAMP NOT NULL,
    lab_staff VARCHAR NOT NULL,
    description TEXT NOT NULL
);

-- PCR extraction kit used for PCR
CREATE TABLE Extraction_Kit(
	id SMALLSERIAL PRIMARY KEY,
    short_name CHAR(10) UNIQUE NOT NULL,
	manufacturer VARCHAR NOT NULL,
    designation VARCHAR
);

-- which filter was used for retrieving the environmental sample
CREATE TABLE Filter_Method(
    id SMALLSERIAL PRIMARY KEY,
    name VARCHAR UNIQUE NOT NULL,
	mesh_width REAL NOT NULL,
    description TEXT
);

-- lineage of a taxon
CREATE TABLE Lineage(
    id SERIAL PRIMARY KEY,
	parent_taxon_id INTEGER,
    grand_taxon_ids INTEGER[]
);

-- where the environmental sample was collected
CREATE TABLE Location(
    short_name CHAR(3) PRIMARY KEY,
	long_name VARCHAR UNIQUE NOT NULL,
    aliases VARCHAR[],
    gps_coordinates POINT NOT NULL,
    stratification_layer VARCHAR NOT NULL,
	description TEXT
);

-- identification results via binocular reading
CREATE TABLE Morph_Experiment(
    experiment_id INTEGER PRIMARY KEY,
    organism_group_id INTEGER NOT NULL,
    individuals_liter INTEGER,
    biomass_mg_m3 REAL,
	size_category REAL
);

-- OTU sequences retrieved by amplicon processing and clustering
CREATE TABLE OTU(
    id SERIAL PRIMARY KEY,
    pipeline_id INTEGER,
	read_count INTEGER,
	sequence VARCHAR,
	taxon_id INTEGER
);

-- list of organism groups uniting multiple taxa
CREATE TABLE Organism_Group(
	id SERIAL PRIMARY KEY,
    name VARCHAR UNIQUE NOT NULL,
    aliases VARCHAR[],
    taxon_ids INTEGER[] NOT NULL,
	description TEXT
);

-- additional criteria used by lab assistants like separation of a taxa by size or developmental stage (larvae)
CREATE TABLE Organism_Group_Count_(
    id SERIAL PRIMARY KEY,
	group_id INTEGER,
	experiment_id INTEGER,
    size_category VARCHAR,
    description TEXT
);

-- Specialization of an experiment with additional information about conducted PCR
CREATE TABLE PCR_Experiment(
    experiment_id INTEGER PRIMARY KEY,
    primer_pair SMALLINT NOT NULL,
    extraction_kit SMALLINT NOT NULL,
 	description TEXT
);

-- bioinformatics protocol
CREATE TABLE Pipeline(
    id SERIAL PRIMARY KEY,
	sequences_id INTEGER,
    protocol TEXT NOT NULL,
    lab_stuff VARCHAR NOT NULL,
	otu_ids INTEGER[]
);

-- plankton type for which the collecting method is selective
CREATE TABLE Plankton_Type(
    id SMALLSERIAL PRIMARY KEY,
	short_name CHAR(20) UNIQUE NOT NULL,
    designation VARCHAR
);

-- associate publications and analyses 
CREATE TABLE Publication(
	id SMALLSERIAL PRIMARY KEY,
	pipeline_id INTEGER NOT NULL,
	doi VARCHAR UNIQUE,
	publication_date DATE NOT NULL,
	description TEXT
);

-- forward and reverse primer sequence used in PCR experiment
CREATE TABLE Primer_Pair(
	id SMALLSERIAL PRIMARY KEY,
    name CHAR(20) UNIQUE,
    name_fwd VARCHAR NOT NULL,
    name_rev VARCHAR NOT NULL,
    sequence_fwd CHAR(40) NOT NULL,
    sequence_rev CHAR(40) NOT NULL,
    target_group VARCHAR NOT NULL,
    target_region VARCHAR NOT NULL,
    product_length INTEGER,
	reference_doi VARCHAR,
    description TEXT
);

-- rank of a taxon (species, genus, family, etc.)
CREATE TABLE Rank(
	id SMALLSERIAL PRIMARY KEY,
    name VARCHAR UNIQUE NOT NULL,
    aliases VARCHAR[]
);

-- time, location, filter info about the collection of an environmental sample
CREATE TABLE Sample(
    id SERIAL PRIMARY KEY,
    sample_name VARCHAR NOT NULL,
    location_id CHAR(3) NOT NULL,
    filter_method SMALLINT NOT NULL,
    dry_method SMALLINT NOT NULL,
    plankton_type SMALLINT NOT NULL,
    volume REAL,
    collection_date DATE NOT NULL
);

-- metadata for sequencing data 
CREATE TABLE Sequences(
	experiment_id INTEGER PRIMARY KEY,
	data_set_name VARCHAR UNIQUE,
	read_count INTEGER NOT NULL,
	server VARCHAR NOT NULL,
	path VARCHAR NOT NULL,
	description TEXT
);

-- a node in the taxonomy of cellular organisms, if provided NCBI and Silva nomenclatura are stored
CREATE TABLE Taxon(
    id SERIAL PRIMARY KEY,
    taxid INTEGER NOT NULL,
    tax_src_id INTEGER NOT NULL,
    tax_names_id INTEGER NOT NULL,
    rank_id INTEGER NOT NULL,
    lineage_id INTEGER NOT NULL,
    UNIQUE(taxid, tax_src_id)
);

-- store scientific names and aliases of taxonomic nodes
CREATE TABLE Taxon_Names(
	id SERIAL PRIMARY KEY,
	taxon_id INTEGER NOT NULL,
	taxon_name VARCHAR NOT NULL,
	aliases VARCHAR[]
);

-- list of source files serving for information extraction for NCBI_Header table
CREATE TABLE Taxonomy_Source(
	id SERIAL PRIMARY KEY,
    name VARCHAR UNIQUE NOT NULL,
    url VARCHAR NOT NULL,
	last_update DATE NOT NULL, 
    description TEXT
);

-- add missing foreign key constraints
ALTER TABLE Sample ADD FOREIGN KEY (dry_method) REFERENCES Dry_Method (id);
ALTER TABLE Lineage ADD FOREIGN KEY (parent_taxon_id) REFERENCES Taxon (id);
ALTER TABLE Morph_Experiment ADD FOREIGN KEY (experiment_id) REFERENCES Experiment (id);
ALTER TABLE Morph_Experiment ADD FOREIGN KEY (organism_group_id) REFERENCES Organism_Group (id);
ALTER TABLE OTU ADD FOREIGN KEY (taxon_id) REFERENCES Taxon(id);
ALTER TABLE OTU ADD FOREIGN KEY (pipeline_id) REFERENCES Pipeline(id);
ALTER TABLE PCR_Experiment ADD FOREIGN KEY (experiment_id) REFERENCES Experiment (id);
ALTER TABLE PCR_Experiment ADD FOREIGN KEY (primer_pair) REFERENCES Primer_Pair (id);
ALTER TABLE PCR_Experiment ADD FOREIGN KEY (extraction_kit) REFERENCES Extraction_Kit (id);
ALTER TABLE Pipeline ADD FOREIGN KEY (sequences_id) REFERENCES Sequences (experiment_id);
ALTER TABLE Publication ADD FOREIGN KEY (pipeline_id) REFERENCES Pipeline (id);
ALTER TABLE Sample ADD FOREIGN KEY (location_id) REFERENCES Location (short_name);
ALTER TABLE Sample ADD FOREIGN KEY (filter_method) REFERENCES Filter_Method (id);
ALTER TABLE Sample ADD FOREIGN KEY (dry_method) REFERENCES Dry_Method (id);
ALTER TABLE Sample ADD FOREIGN KEY (plankton_type) REFERENCES Plankton_Type (id);
ALTER TABLE Taxon ADD FOREIGN KEY (tax_names_id) REFERENCES Taxon_Names (id);
ALTER TABLE Taxon ADD FOREIGN KEY (lineage_id) REFERENCES Lineage (id);
ALTER TABLE Taxon ADD FOREIGN KEY (rank_id) REFERENCES Rank (id);


-- trigger for insertion on Experiment to test list of sample ids to match primary key in table Sample
CREATE OR REPLACE FUNCTION sample_check() RETURNS trigger AS $sample_check$
DECLARE
    sample_id int;
BEGIN
    FOREACH sample_id IN ARRAY NEW.sample_ids LOOP
        IF  sample_id NOT IN (SELECT id FROM Sample) THEN
            RAISE EXCEPTION 'sample_id % not registered in Samples', sample_id;
		END IF;
    END LOOP;
END;
$sample_check$ LANGUAGE PLPGSQL;

CREATE TRIGGER sample_check
    BEFORE INSERT OR UPDATE
    ON Experiment
    FOR EACH ROW EXECUTE PROCEDURE sample_check();
