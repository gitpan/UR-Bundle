#!/usr/bin/env perl

use strict;
use warnings;

#BEGIN { $ENV{UR_CONTEXT_BASE} = "URT::Context::Testing" };

use File::Basename;
use lib File::Basename::dirname(__FILE__)."/../..";
use URT;
use DBI;
use IO::Pipe;
use Test::More;
if ($INC{"UR.pm"} =~ /blib/) {
    plan skip_all => 'The test harness insists on making our db unwritable.  Run me individually or fix me!';
}
else {
    plan tests => 90;
}

use UR::Namespace::Command::Update::Classes;
UR::DBI->no_commit(1);

# This can only be run with the cwd at the top of the URT namespace

require Cwd;
my $working_dir = Cwd::abs_path();
if ($working_dir !~ m/\/URT/) {
    my($urt_dir) = ($INC{'URT.pm'} =~ m/^(.*)\.pm$/);
    if (-d $urt_dir) {
        chdir($urt_dir);
    } else {
        die "Cannot determine URT's namespace directory, exiting";
    }
}


# Make a fresh sqlite database in tmp.

my $ds_class = 'URT::DataSource::SomeSQLite';
$ds_class->class;
my $path = $INC{"UR.pm"};
system "chmod -R o+w $path";

my $sqlite_file = $ds_class->server;

cleanup_files();

sub cleanup_files {
    unlink $sqlite_file;

    for my $filename (
        qw|
            Car.pm
            Employee.pm
            Person.pm
            .deleted/Car.pm
            .deleted/Employee.pm
            .deleted/Person.pm
        |
    ) {
        if (-e $filename) {
            #warn "unlinking $filename\n";
            unlink $filename;
        }
    }
}

UR::Namespace::Command::Update::Classes->dump_error_messages(1);
UR::Namespace::Command::Update::Classes->dump_warning_messages(1);
UR::Namespace::Command::Update::Classes->dump_status_messages(0);
UR::Namespace::Command::Update::Classes->status_messages_callback(
    sub {
        my $self = shift;
        my $msg = shift;
        print "   $msg\n";
        return 1;
    }
);

# We launch a similar command multiple times.

my($delegate_class,$create_params) = UR::Namespace::Command::Update::Classes->resolve_class_and_params_for_argv(qw(--data-source URT::DataSource::SomeSQLite));
ok($delegate_class, "Resolving parameters for update: class is $delegate_class");
my $command_obj = sub {
    my $command_obj = $delegate_class->create(%$create_params, _override_no_commit_for_filesystem_items => 1);
    ok($command_obj, "created new command for " . join(" ", @_));
    ok($command_obj->execute(), "executed new command for " . join(" ",@_));
    return $command_obj->result;
};
bless ($command_obj,"DummyExecutor");
sub DummyExecutor::execute {
    shift->(@_);
}

ok($command_obj, "Created a dummy command object for updating the classes");

my $dbh = $ds_class->get_default_dbh();
ok($dbh, 'Got database handle');

# This wrapper to get_changes filters out things like the command-line parameters
# until that bug is fixed.

my $trans;
sub get_changes {
    my @changes =
        grep { $_->changed_class_name ne 'UR::Namespace::Command::Update::Classes' }
        grep { $_->changed_class_name ne "UR::Namespace::CommandParam" }
        grep { $_->changed_class_name ne 'UR::DataSource::Meta' && substr($_->changed_aspect,0,1) ne '_'}
        $trans->get_change_summary();
    return @changes;
}

sub cached_dd_objects {
    my $cx = UR::Context->current;
    my @obj =
        grep { ref($_) =~ /::DB::/ }
        $cx->all_objects_loaded('UR::Object'), $cx->all_objects_loaded('UR::Object::Ghost');
}

sub cached_dd_object_count {
    my $cx = UR::Context->current;
    my @obj =
        grep { ref($_) =~ /::DB::/ }
        $cx->all_objects_loaded('UR::Object'), $cx->all_objects_loaded('UR::Object::Ghost');
    return scalar(@obj);
}

sub cached_class_object_count {
    my $cx = UR::Context->current;
    my @obj =
        grep { ref($_) =~ /UR::Object::/ }
        $cx->all_objects_loaded('UR::Object'), $cx->all_objects_loaded('UR::Object::Ghost');
    return scalar(@obj);
}

sub cached_person_dd_objects {
    my $cx = UR::Context->current;
    my @obj =
        grep { $_->{table_name} eq "person" }
        grep { ref($_) =~ /::DB::/ }
        $cx->all_objects_loaded('UR::Object'), $cx->all_objects_loaded('UR::Object::Ghost');
}

sub cached_person_summary {
    my @obj = map { ref($_) . "\t" . $_->{id} } cached_person_dd_objects();
    return @obj;
}

sub undo_log_summary {
    my @c = do { no warnings; reverse @UR::Context::Transaction::change_log; };
    return
        map { $_->{changed_class_name} . "\t" . $_->{changed_id} . "\t" . $_->{changed_aspect} }
        grep { not ($_->{changed_class_name} =~ /^UR::Object/ and $_->{changed_aspect} eq "load") }
        @c;
}


# Hack - These get filled in at the bottom initialize_check_changes_data_structure()
our($check_changes_1, $check_changes_2, $check_changes_3);
# Empty schema

$trans = UR::Context::Transaction->begin();
ok($trans, "began transaction");

    ok($command_obj->execute(),'Executing update on an empty schema');

    my @changes = get_changes();
    is(scalar(@changes),1, "one change for an empty schema");
    is($changes[0]->changed_class_name, 'URT::DataSource::Meta', 'Single change was to URT::DataSource::Meta');
    is($changes[0]->changed_aspect, 'connect', 'Single change was a DB connect');
    

    # note this for comparison in future tests.
    my $expected_dd_object_count = cached_dd_object_count();

    # don't rollback

# Make a table

ok($dbh->do('CREATE TABLE person (person_id integer NOT NULL PRIMARY KEY, name varchar)'), 'Create person table');
$trans = UR::Context::Transaction->begin();
ok($trans, "CREATED PERSON and began transaction");

        ok($command_obj->execute(),'Executing update after creating person table');

        initialize_check_change_data_structures();
        @changes = get_changes();
        # FIXME The test should probably break out each type of changed thing and check
        # that the counts of each type are correct, and not just the count of all changes
        my $changes_as_hash = convert_change_list_for_checking(@changes);
        is_deeply($changes_as_hash, $check_changes_1, "Change list is correct");

        my $personclass = UR::Object::Type->get('URT::Person');
        isa_ok($personclass, 'UR::Object::Type');  # FIXME why isn't this a UR::Object::Type
        ok($personclass->module_source_lines, 'Person class module has at least one line');
        is($personclass->type_name, 'person', 'Person class type_name is correct');
        is($personclass->class_name, 'URT::Person', 'Person class class_name is correct');
        is($personclass->table_name, 'PERSON', 'Person class table_name is correct');
        is($UR::Context::current->resolve_data_sources_for_class_meta_and_rule($personclass)->id, $ds_class, 'Person class data_source is correct');
        is_deeply([sort $personclass->direct_column_names],
                ['NAME','PERSON_ID'],
                'Person object has all the right columns');
        is_deeply([$personclass->direct_id_column_names],
                ['PERSON_ID'],
                'Person object has all the right id column names');

        # Another test case should make sure the other class introspection methods like inherited_property_names,
        # all_table_names, etc work correctly for all kinds of objects

        my $module_path = $personclass->module_path;
        ok($module_path, "got a module path");
        ok(-f $module_path, 'Person.pm module exists');

        ok(! UR::Object::Type->get('URT::NonExistantClass'), 'Correctly cannot load a non-existant class');

        $trans->rollback;
        ok($trans->isa("UR::DeletedRef"), "rolled-back transaction");
        is(cached_dd_object_count(), $expected_dd_object_count, "no data dictionary objects cached after rollback");

# Make the employee and car tables refer to person, and add a column to person

ok($dbh->do('CREATE TABLE employee (employee_id integer NOT NULL PRIMARY KEY CONSTRAINT fk_person_id REFERENCES person(person_id), rank integer)'), 'Employee inherits from Person');
ok($dbh->do('ALTER TABLE person ADD COLUMN postal_address varchar'), 'Add column to Person');
ok($dbh->do('CREATE TABLE car (car_id integer NOT NULL PRIMARY KEY, owner_id integer NOT NULL CONSTRAINT fk_person_id2 REFERENCES person(person_id), make varchar, model varchar, color varchar, cost number)'), 'Create car table');

#print join("\n",sort map { values %$_ } values %$UR::Context::all_objects_loaded);

$trans = UR::Context::Transaction->begin();
ok($trans, "CREATED EMPLOYEE AND CAR AND UPDATED PERSON and began transaction");

    ok($command_obj->execute(), 'Updating schema');
    @changes = get_changes();
    $changes_as_hash = convert_change_list_for_checking(@changes);
    is_deeply($changes_as_hash, $check_changes_2, "Change list is correct");

    # Verify the Person.pm and Employee.pm modules exist

    $personclass = UR::Object::Type->get('URT::Person');
    ok($personclass, 'Person class loaded');
    is_deeply([sort $personclass->direct_column_names],
            ['NAME','PERSON_ID','POSTAL_ADDRESS'],
            'Person object has all the right columns');
    is_deeply([sort $personclass->class_name->__meta__->all_property_names],
            ['name','person_id','postal_address'],
            'Person object has all the right properties');
    is_deeply([$personclass->direct_id_column_names],
            ['PERSON_ID'],
            'Person object has all the right id column names');

    my $employeeclass = UR::Object::Type->get('URT::Employee');
    ok($employeeclass, 'Employee class loaded');
    isa_ok($employeeclass, 'UR::Object::Type');

    # There is no standardized way to spot inheritance from the schema.
    # The developer can reclassify in the source, and subsequent updates would respect it.
    # FIXME: test for this.
    # What about if one class' primary keys are all foreign keys to all of another class' primary keys?
    # FIXME - what about foreign keys not involving primary keys?  Make object accessor properties

    ok(! $employeeclass->isa('URT::Car'), 'Employee class is correctly not a Car');
    ok($employeeclass->module_source_lines, 'Employee class module has at least one line');

    is_deeply([sort $employeeclass->direct_column_names],
            ['EMPLOYEE_ID','RANK'],
            'Employee object has all the right columns');
    is_deeply([sort $employeeclass->class_name->__meta__->all_property_names],
            ['employee_id','person_employee','rank'],
            'Employee object has all the right properties');
    is_deeply([$employeeclass->direct_id_column_names],
             ['EMPLOYEE_ID'],
            'Employee object has all the right id column names');
    ok($employeeclass->table_name eq 'EMPLOYEE', 'URT::Employee object comes from the employee table');


    my $carclass = UR::Object::Type->get('URT::Car');
    ok($carclass, 'Car class loaded');
    is($carclass->class_name,'URT::Car', "class name is set correctly");
    isa_ok($carclass,'UR::Object::Type');
    ok(! $carclass->class_name->isa('URT::Person'), 'Car class is correctly not a Person');

    is_deeply([sort $carclass->direct_column_names],
            ['CAR_ID','COLOR','COST','MAKE','MODEL','OWNER_ID'],
            'Car object has all the right columns');
    # Is owner a property through owner_id?
    is_deeply([sort $carclass->class_name->__meta__->all_property_names],
            ['car_id','color','cost','make','model','owner_id','person_owner'],
            'Car object has all the right properties');
    is_deeply([$carclass->direct_id_column_names],
            ['CAR_ID'],
            'Car object has all the right id column names');
        ok($carclass->table_name eq 'CAR', 'Car object comes from the car table');

    $trans->rollback;
    ok($trans->isa("UR::DeletedRef"), "rolled-back transaction");
    is(cached_dd_object_count(), $expected_dd_object_count, "no data dictionary objects cached after rollback");

# Drop a table

ok($dbh->do('DROP TABLE car'),'Removed Car table');
$trans = UR::Context::Transaction->begin();
ok($trans, "DROPPED CAR and began transaction");

    ok($command_obj->execute(), 'Updating schema');
    @changes = get_changes();
    $changes_as_hash = convert_change_list_for_checking(@changes);
    is_deeply($changes_as_hash, $check_changes_3, "Change list is correct");

    ok($personclass = UR::Object::Type->get('URT::Person'),'Loaded Person class');
    ok($employeeclass = UR::Object::Type->get('URT::Employee'), 'Loaded Employee class');

    $carclass = UR::Object::Type->get('URT::Car');
    ok(!$carclass, 'Car class is correctly not loaded');

    $trans->rollback;
    ok($trans->isa("UR::DeletedRef"), "rolled-back transaction");
    is(cached_dd_object_count(), $expected_dd_object_count, "no data dictionary objects cached after rollback");


# Drop a constraint
# SQLite doesn't support altering a table to drop a constraint, so we need to
# drop the table and recreate it without the constraint
#ok($dbh->do('DROP TABLE employee'), 'Temporarily dropping table employee');
#ok($dbh->do('CREATE TABLE employee (employee_id integer NOT NULL PRIMARY KEY, rank integer)'), 'Recreate Employee without constraint');
#$trans = UR::Context::Transaction->begin();
#ok($trans, "Changed EMPLOYEE and began transaction");
#
#    ok($command_obj->execute(), 'Updating schema');
#    my @o = UR::DataSource::RDBMS::FkConstraint->get(namespace => 'URT');
#print "\n\n*** Got ",scalar(@o)," FkConstraints\n";
#    @changes = get_changes();
#    $changes_as_hash = convert_change_list_for_checking(@changes);
#


# Drop the other two tables

ok($dbh->do('DROP TABLE employee'),'Removed employee table');
ok($dbh->do('DROP TABLE person'),'Removed person table');
ok($dbh->do('CREATE TABLE person (person_id integer NOT NULL PRIMARY KEY, postal_address varchar)'), 'Replaced table person w/o column "name".');
    #ok($dbh->do('ALTER TABLE person DROP column name'),'Removed the name column from the person table'); ##<won't work
$trans = UR::Context::Transaction->begin();
ok($trans, "DROPPED EMPLOYEE AND UPDATED PERSON began transaction");

    ok($command_obj->execute(), 'Updating schema');
    @changes = get_changes();
    is(scalar(@changes), 15, "found changes for two more dropped tables");


$trans = UR::Context::Transaction->begin();
ok($trans, "Restarted transaction since some data is not really sync'd at sync_filesystem");
ok($command_obj->execute(), 'Updating schema anew.');


    ok(! UR::Object::Type->get('URT::Employee'), 'Correctly could not load Employee class');
    ok(! UR::Object::Type->get('URT::Car'),'Correctly could not load Car class');

    $personclass = UR::Object::Type->get('URT::Person');
    $personclass->ungenerate;
    $DB::single = 1;
    $personclass->generate;
    ok($personclass, 'Person class loaded');
    is_deeply([sort $personclass->direct_column_names],
            ['PERSON_ID','POSTAL_ADDRESS'],
            'Person object has all the right columns');
    is_deeply([sort $personclass->class_name->__meta__->all_property_names],
            ['person_id','postal_address'],
            'Person object has all the right properties');
    is_deeply([$personclass->direct_id_column_names],
            ['PERSON_ID'],
            'Person object has all the right id column names');

    $trans->rollback;
    ok($trans->isa("UR::DeletedRef"), "rolled-back transaction");
    is(cached_dd_object_count(), $expected_dd_object_count, "no data dictionary objects cached after rollback");

# Clean up after now-defunct class module files and SQLIte DB file

cleanup_files();

sub child_db_interaction {
my $dbfile = shift;

    my $pid;
    my $result = IO::Pipe->new();
    my $to_child = IO::Pipe->new();
    if ($pid = fork()) {
        $to_child->writer;
        $to_child->autoflush(1);
        $result->reader();
        my @commands = map {$_ . "\n"} @_;

        foreach my $cmd ( @commands ) {
            $to_child->print($cmd);

            my $result = $result->getline();
            chomp($result);
            my($retval,$string,$dbierr) = split(';',$result);
            return undef unless $retval;
        }

        $to_child->print("exit\n");
        waitpid($pid,0);
        return 1;

    } else {
        $to_child->reader();
        $result->writer();
        $result->autoflush(1);

        my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
        unless ($dbh) {
            $result->print("0;can't connect;$DBI::errstr\n");
            exit(1);
        }

        while(my $sql = $to_child->getline()) {
            chomp($sql);
            last if ($sql eq 'exit' || !$sql);

            my $sth = $dbh->prepare($sql);
            unless ($sth) {
                $result->print("0;prepare failed;$DBI::errstr\n");
                $result->print("0;prepare failed;$DBI::errstr\n");
                next;
            }
            my $retval = $sth->execute();
            if ($retval) {
                $result->print($retval . "\n");
            } else {
                $result->print("0;execute failed;$DBI::errstr\n");
            }
        }
        $dbh->commit();

        exit(0);
    } # end child
}


# Convert the list of changes to a data structure matching the expected changes
sub convert_change_list_for_checking {
    my(@changes_list) = @_;

    my $changes = {};
    foreach my $change ( @changes_list ) {
        my $changed_class_name = $change->{'changed_class_name'};
        my $changed_id = $change->{'changed_id'};
        my $changed_aspect = $change->{'changed_aspect'};
        my $undo_data = $change->{'undo_data'};
        if (exists $changes->{$changed_class_name}->{$changed_id}->{$changed_aspect}) {
            die "Two types of changes for the same thing in the same transaction!?";
        }

        $changes->{$changed_class_name}->{$changed_id}->{$changed_aspect} = defined($undo_data);
    }

    return $changes;
}
    

    
# These expected change data structures work like this:
# Based on the UR::Change objects, the first level hash key is
# the changed_class_name, second level key is the changed_id,
# the third level key is the changed_aspect, and the final value
# is whether the undo_data is defined or not.
#
# Note that because of the way this testcase works, by creating a
# transaction, updating metadata, and the rolling back the transaction,
# all these metadata objects are always "created" as new, and not
# modifications of existing things.
#
# There should probably be tests for the usual case where you would be
# updating existing classes based on DB changes

# Changes after creating the person table and running ur update classes

sub initialize_check_change_data_structures {
    $check_changes_1 = {
    'UR::DataSource::RDBMS::Table' => {
        "URT::DataSource::SomeSQLite\t\tPERSON" => {
            create => '',    # Meta DB object is created for the person table
            er_type => '',    # And ur update classes fills in an er_type
         },
    },
    'UR::DataSource::RDBMS::TableColumn' => {
        # The (new) person table has 2 (new) columns, person_id and name
        "URT::DataSource::SomeSQLite\t\tPERSON\tPERSON_ID" => {
            create => ''
        },
        "URT::DataSource::SomeSQLite\t\tPERSON\tNAME" => {
            create => ''
        },
    },
    'UR::DataSource::RDBMS::PkConstraintColumn' => {
        # person_id is the first and only primary column constraint
        "URT::DataSource::SomeSQLite\t\tPERSON\tperson_id\t1" => {
            create => ''
        },
    },
    'UR::Object::Type' => {
        # A new metaclass gets created for the person table
        'URT::Person::Type' => {
            create => ''
        },
    },
    'URT::Person::Type' => {
        'URT::Person' => {
            create => '', # And then the class that goes with the table
            rewrite_module_header => 1, # And a record that we wrote a perl module on the filesystem
        },
    },
    'UR::Object::Property' => {
        # Two new properties for the person class, name and person_id
        "URT::Person\tname" => {
            create => ''
        }, 
        "URT::Person\tperson_id" => {
            create => ''
        },
    },
    'UR::Object::Property::ID' => {
        "person\t1" => { # and the ID property that goes with the primary key constraint
            create => ''
        },
    }
};
                        

# Changes after creating the car and employee tables, and adding postal_address column to person
    $check_changes_2 = {
    'UR::DataSource::RDBMS::Table' => {
        # 3 tables: person, employee and car
        "URT::DataSource::SomeSQLite\t\tPERSON" => {
            create => '',
            er_type => '',
        },
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE" => {
            create => '',
            er_type => '',
        },
        "URT::DataSource::SomeSQLite\t\tCAR" => {
            create => '',
            er_type => '',
        },
    },

    'UR::DataSource::RDBMS::TableColumn' => {
        # Table person now has 3 columns: person_id, name and postal_address
        "URT::DataSource::SomeSQLite\t\tPERSON\tPERSON_ID" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tPERSON\tNAME" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tPERSON\tPOSTAL_ADDRESS" => {
            create => '',
        },
        # table employee has 2 columns: employee_id and rank
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE\tEMPLOYEE_ID" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE\tRANK" => {
            create => '',
        },
        # table car has these columns: car_id, make, model, color and cost
        "URT::DataSource::SomeSQLite\t\tCAR\tCAR_ID" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tCAR\tMAKE" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tCAR\tMODEL" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tCAR\tCOLOR" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tCAR\tCOST" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tCAR\tOWNER_ID" => {
            create => '',
        },
    },

    'UR::DataSource::RDBMS::FkConstraint' => {
       # Both employee and car tables have foreign keys to person
        "URT::DataSource::SomeSQLite\t\t\tEMPLOYEE\tPERSON\tFK_PERSON_ID" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\t\tCAR\tPERSON\tFK_PERSON_ID2" => {
            create => '',
        },
    },

    'UR::DataSource::RDBMS::FkConstraintColumn' => {
        # The employee table FK points from employee_id to person_id
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE\tFK_PERSON_ID\tEMPLOYEE_ID" => {
            create => '',
        },
        # The car table FK points from owner_id to person_id
        "URT::DataSource::SomeSQLite\t\tCAR\tFK_PERSON_ID2\tOWNER_ID" => {
            create => '',
        }
    },

    'UR::DataSource::RDBMS::PkConstraintColumn' => {
        # All three tables have PK constraints for their ID columns
        "URT::DataSource::SomeSQLite\t\tPERSON\tperson_id\t1" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE\temployee_id\t1" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tCAR\tcar_id\t1" => {
            create => '',
        },
    },

    # running ur update classes makes 3 new classes
    'UR::Object::Type' => {
        "URT::Car::Type" => {
            create => '',
        },
        "URT::Employee::Type" => {
            create => '',
        },
        "URT::Person::Type" => {
            create => '',
        },
    },
  
    # Each class has a property for the respective tablecolumn
    'UR::Object::Property' => {
        "URT::Car\tcar_id" => {
            create => '',
        },
        "URT::Car\tcolor" => {
            create => '',
        },
        "URT::Car\tcost" => {
            create => '',
        },
        "URT::Car\tmake" => {
            create => '',
        },
        "URT::Car\tmodel" => {
            create => '',
        },
        "URT::Car\towner_id" => {
            create => '',
        },
        "URT::Car\tperson_owner" => {
            create => '',
        },

        "URT::Employee\temployee_id" => {
           create => '',
        },
        "URT::Employee\trank" => {
           create => '',
        },
        "URT::Employee\tperson_employee" => {
            create => '',
        },

        "URT::Person\tname" => {
           create => '',
        },
        "URT::Person\tperson_id" => {
           create => '',
        },
        "URT::Person\tpostal_address" => {
           create => '',
        },
    },

    # Each class has an ID property
    'UR::Object::Property::ID' => {
        "car\t1" => {
            create => '',
        },
        "employee\t1" => {
            create => '',
        },
        "person\t1" => {
            create => '',
        },
    },

    # each foreign key has a related reference 
    'UR::Object::Reference' => {
        'URT::Car::person_owner' => {
            create => '',
        },
        'URT::Employee::person_employee' => {
            create => '',
        },
    },

    # and each FK column has a related reference property
    'UR::Object::Reference::Property' => {
        "URT::Employee::person_employee\t1" => {
            create => '',
        },
        "URT::Car::person_owner\t1" => {
            create => '',
        },
    },

    # There a record of creating an instance of each class, and 
    # that we wrote a perl module on the filesystem
    'URT::Car::Type' => {
        'URT::Car' => {
            create => '',
            rewrite_module_header => 1,
        },
    },
    'URT::Employee::Type' => {
        'URT::Employee' => {
            create => '',
            rewrite_module_header => 1,
        },
    },
    'URT::Person::Type' => {
        'URT::Person' => {
            create => '',
            rewrite_module_header => 1,
        },
    },

    # Because we rolled back the previous transaction, the old metadata
    # objects became ghosts.  This is suboptimal and makes little sense
    # but there it is...
    'UR::DataSource::RDBMS::Table::Ghost' => {
        "URT::DataSource::SomeSQLite\t\tPERSON" => {
            delete => 1,
        },
    },
    'UR::DataSource::RDBMS::TableColumn::Ghost' => {
        "URT::DataSource::SomeSQLite\t\tPERSON\tPERSON_ID" => {
            delete => 1,
        },
        "URT::DataSource::SomeSQLite\t\tPERSON\tNAME" => {
            delete => 1,
        },
    },
    'UR::DataSource::RDBMS::PkConstraintColumn::Ghost' => {
        "URT::DataSource::SomeSQLite\t\tPERSON\tperson_id\t1" => {
            delete => 1,
        },
    },
};



# After removing the car table
    $check_changes_3 = {
    # FIXME Why are there no ghost objects for the dropped car stuff?

    'UR::DataSource::RDBMS::Table' => {
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE" => {
            create => '',
            er_type => '',
        },
        "URT::DataSource::SomeSQLite\t\tPERSON" => {
            create => '',
            er_type => '',
        },
    },

    'UR::DataSource::RDBMS::TableColumn' => {
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE\tEMPLOYEE_ID" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE\tRANK" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tPERSON\tPERSON_ID" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tPERSON\tNAME" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tPERSON\tPOSTAL_ADDRESS" => {
            create => '',
        },
    },

    'UR::DataSource::RDBMS::FkConstraint' => {
        "URT::DataSource::SomeSQLite\t\t\tEMPLOYEE\tPERSON\tFK_PERSON_ID" => {
            create => '',
        },
    },

    'UR::DataSource::RDBMS::FkConstraintColumn' => {
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE\tFK_PERSON_ID\tEMPLOYEE_ID" => {
            create => '',
        },
    },

    'UR::DataSource::RDBMS::PkConstraintColumn' => {
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE\temployee_id\t1" => {
            create => '',
        },
        "URT::DataSource::SomeSQLite\t\tPERSON\tperson_id\t1" => {
            create => '',
        },
    },


    'URT::Employee::Type' => {
        'URT::Employee' => {
            create => '',
            rewrite_module_header => 1,
        },
    },
    'URT::Person::Type' => {  
        'URT::Person' => {
           create => '',
            rewrite_module_header => 1,
        },
    },

    'UR::Object::Type' => {
        'URT::Person::Type' => {
            create => '',
        },
        'URT::Employee::Type' => {
            create => '',
        },
    },

    'UR::Object::Property' => {
        "URT::Employee\temployee_id" => {
            create => '',
        },
        "URT::Employee\trank" => {
            create => '',
        },
        "URT::Employee\tperson_employee" => {
            create => '',
        },

        "URT::Person\tperson_id" => {
            create => '',
        },
        "URT::Person\tname" => {
            create => '',
        },
        "URT::Person\tpostal_address" => {
            create => '',
        },
    },

    'UR::Object::Property::ID' => {
        "employee\t1" => {
            create => '',
        },
        "person\t1" => {
            create => '',
        },
    },

    'UR::Object::Reference' => {
        "URT::Employee::person_employee" => {
            create => '',
        },
    },

    'UR::Object::Reference::Property' => {
        "URT::Employee::person_employee\t1" => {
            create => '',
        },
    },

    'UR::DataSource::RDBMS::Table::Ghost' => {
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE" => {
            delete => 1,
        },
        "URT::DataSource::SomeSQLite\t\tPERSON" => {
            delete => 1,
        },
    },
    'UR::DataSource::RDBMS::TableColumn::Ghost' => {
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE\tEMPLOYEE_ID" => {
            delete => 1,
        },
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE\tRANK" => {
            delete => 1,
        },
        "URT::DataSource::SomeSQLite\t\tPERSON\tPERSON_ID" => {
            delete => 1,
        },
        "URT::DataSource::SomeSQLite\t\tPERSON\tNAME" => {
            delete => 1,
        },
        "URT::DataSource::SomeSQLite\t\tPERSON\tPOSTAL_ADDRESS" => {
            delete => 1,
        },
    },
    'UR::DataSource::RDBMS::FkConstraint::Ghost' => {
        "URT::DataSource::SomeSQLite\t\t\tEMPLOYEE\tPERSON\tFK_PERSON_ID" => {
            delete => 1,
        },
    },
    'UR::DataSource::RDBMS::FkConstraintColumn::Ghost' => {
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE\tFK_PERSON_ID\tEMPLOYEE_ID" => {
            delete => 1,
        },
    },
    'UR::DataSource::RDBMS::PkConstraintColumn::Ghost' => {
        "URT::DataSource::SomeSQLite\t\tEMPLOYEE\temployee_id\t1" => {
            delete => 1,
        },
        "URT::DataSource::SomeSQLite\t\tPERSON\tperson_id\t1" => {
            delete => 1,
        },
    },

};
}

1;
