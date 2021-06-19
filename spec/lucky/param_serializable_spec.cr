require "../spec_helper"

include ContextHelper
include MultipartHelper

class BasicParams
  include Lucky::ParamSerializable
  skip_param_key

  property string : String
  property int16 : Int16
  property int32 : Int32
  property int64 : Int64
  property bool : Bool
  property float64 : Float64
  property uuid : UUID
  property blank : String?
end

class UserWithKeyParams
  include Lucky::ParamSerializable
  param_key :user

  property name : String
  property age : Int32
  property fellowship : String?
end

class ComplexParams
  include Lucky::ParamSerializable

  property tags : Array(String)
  property numbers : Array(Int32)
  property default : Bool = true
  @[Lucky::ParamField(param_key: :override)]
  property version : Float64
  @[Lucky::ParamField(ignore: true)]
  property internal : Int32 = 4
end

class CrashingParams
  include Lucky::ParamSerializable
  skip_param_key

  property required_but_missing : String
  @[Lucky::ParamField(param_key: :key)]
  property wrong : Bool
end

class ParamsWithFile
  include Lucky::ParamSerializable
  param_key :data

  property avatar : Lucky::UploadedFile
  property docs : Array(Lucky::UploadedFile)
end

class LocationParams
  include Lucky::ParamSerializable
  param_key :location

  property lat : Float64
  property lng : Float64
end

class AddressParams
  include Lucky::ParamSerializable
  param_key :address

  property street : String
  property location : LocationParams
end

class ActorParams
  include Lucky::ParamSerializable
  param_key :actor

  property name : String = "George"
  property age : Int32?
end

describe Lucky::ParamSerializable do
  describe "param_key" do
    it "checks the key on all params" do
      request = build_request
      request.query = "user:name=Gandalf&user:age=11000&fellowship=bracelet"

      params = Lucky::Params.new(request)
      user_params = UserWithKeyParams.from_params(params)

      user_params.name.should eq("Gandalf")
      user_params.age.should eq(11000)
      user_params.fellowship.should be_nil
    end
  end

  describe "original_source" do
    it "returns the original params used to create the object" do
      request = build_request
      params = Lucky::Params.new(request)
      actor_params = ActorParams.from_params(params)

      actor_params.original_source.should eq(params)
    end
  end

  describe "has_source?" do
    it "returns true when the original_source received the key" do
      request = build_request
      request.query = "actor:name=Jim"

      params = Lucky::Params.new(request)
      actor_params = ActorParams.from_params(params)

      actor_params.name.should eq("Jim")
      actor_params.age.should eq(nil)
      actor_params.has_source?("name").should be_true
      actor_params.has_source?("age").should be_false
    end
  end

  describe "handling errors" do
    it "raises an exception when the required value is missing" do
      request = build_request
      request.query = "wrong=true"
      params = Lucky::Params.new(request)

      expect_raises(Lucky::MissingParamError) do
        CrashingParams.from_params(params)
      end
    end
  end

  describe "query params" do
    it "parses the basic param types" do
      request = build_request
      request.query = "string=Test&int16=1&int32=123&int64=12341234&bool=true&float64=3.14&uuid=d65869ee-f08f-47ff-b15d-568dc23c2eb7&fellowship=bracelet"

      run_basic_assertions(request)
    end

    it "parses more complex param types" do
      request = build_request
      request.query = "complex_params:tags[]=one&complex_params:tags[]=two&complex_params:numbers[]=1&complex_params:numbers[]=2&override:version=0.1&complex_params:internal=2"

      run_complex_assertions(request)
    end
  end

  describe "form params" do
    it "parses the basic param types" do
      request = build_request body: "string=Test&int16=1&int32=123&int64=12341234&bool=true&float64=3.14&uuid=d65869ee-f08f-47ff-b15d-568dc23c2eb7&fellowship=bracelet",
        content_type: "application/x-www-form-urlencoded"

      run_basic_assertions(request)
    end

    it "parses more complex param types" do
      request = build_request body: "complex_params:tags[]=one&complex_params:tags[]=two&complex_params:numbers[]=1&complex_params:numbers[]=2&override:version=0.1",
        content_type: "application/x-www-form-urlencoded"

      run_complex_assertions(request)
    end
  end

  describe "json params" do
    it "parses the basic param types" do
      json = {string: "Test", int16: 1, int32: 123, int64: 12341234, bool: true, float64: 3.14, uuid: "d65869ee-f08f-47ff-b15d-568dc23c2eb7", fellowship: "bracelet"}
      request = build_request body: json.to_json, content_type: "application/json"

      run_basic_assertions(request)
    end

    it "parses more complex param types" do
      json = {complex_params: {tags: ["one", "two"], numbers: [1, 2]}, override: {version: 0.1}}
      request = build_request body: json.to_json, content_type: "application/json"

      run_complex_assertions(request)
    end
  end

  describe "multipart params" do
    it "parses the basic param types" do
      request = build_multipart_request form_parts: {
        "string" => "Test", "int16" => "1", "int32" => "123", "int64" => "12341234", "bool" => "true", "float64" => "3.14",
        "uuid" => "d65869ee-f08f-47ff-b15d-568dc23c2eb7", "fellowship" => "bracelet",
      }

      run_basic_assertions(request)
    end

    it "parses more complex param types" do
      request = build_multipart_request form_parts: {
        "complex_params:tags" => ["one", "two"], "complex_params:numbers" => ["1", "2"],
        "override:version" => "0.1",
      }

      run_complex_assertions(request)
    end

    describe "with files" do
      it "parses with an UploadedFile" do
        request = build_multipart_request file_parts: {
          "data:avatar" => "file_contents",
          "data:docs"   => ["file1", "file2"],
        }

        params = Lucky::Params.new(request)
        file_params = ParamsWithFile.from_params(params)

        file_params.avatar.should be_a(Lucky::UploadedFile)
        file_params.docs.size.should eq(2)
        File.read(file_params.avatar.path).should eq "file_contents"
        File.read(file_params.docs.last.path).should eq "file2"
      end
    end
  end

  context "with associated objects" do
    it "serializes the associated object" do
      request = build_request
      request.query = "address:street=123+street&address:location:lat=1.1&address:location:lng=-1.2"

      params = Lucky::Params.new(request)
      address_params = AddressParams.from_params(params)

      address_params.street.should eq("123 street")
      address_params.location.should be_a(LocationParams)
      address_params.location.lat.should eq(1.1)
      address_params.location.lng.should eq(-1.2)
    end
  end
end

private def run_basic_assertions(req : HTTP::Request)
  params = Lucky::Params.new(req)
  user_params = BasicParams.from_params(params)

  user_params.string.should eq("Test")
  user_params.int16.should eq(1_i16)
  user_params.int32.should eq(123_i32)
  user_params.int64.should eq(12341234_i64)
  user_params.bool.should eq(true)
  user_params.float64.should eq(3.14)
  user_params.uuid.should eq(UUID.new("d65869ee-f08f-47ff-b15d-568dc23c2eb7"))
  user_params.blank.should be_nil
  user_params.responds_to?(:fellowship).should be_false
end

private def run_complex_assertions(req : HTTP::Request)
  params = Lucky::Params.new(req)
  complex_params = ComplexParams.from_params(params)

  complex_params.tags.should eq(["one", "two"])
  complex_params.numbers.should eq([1, 2])
  complex_params.default.should eq(true)
  complex_params.version.should eq(0.1)
  complex_params.internal.should eq(4)
end